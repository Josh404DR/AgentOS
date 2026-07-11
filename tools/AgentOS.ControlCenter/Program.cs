using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace AgentOSControlCenter
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm(FindRoot()));
        }

        private static string FindRoot()
        {
            var candidates = new[] { AppDomain.CurrentDomain.BaseDirectory, Environment.CurrentDirectory };
            foreach (var candidate in candidates)
            {
                var current = new DirectoryInfo(candidate);
                while (current != null)
                {
                    if (File.Exists(Path.Combine(current.FullName, "config", "runtime_registry.json")) &&
                        File.Exists(Path.Combine(current.FullName, "config", "script_registry.json"))) return current.FullName;
                    current = current.Parent;
                }
            }
            throw new InvalidOperationException("Cannot locate AgentOS root containing both runtime and script registries.");
        }
    }

    internal sealed class MainForm : Form
    {
        private readonly string root;
        private readonly DataGridView grid = new DataGridView();
        private readonly Label summary = new Label();
        private readonly TextBox output = new TextBox();
        private readonly JavaScriptSerializer json = new JavaScriptSerializer();
        private List<Dictionary<string, object>> runtimes = new List<Dictionary<string, object>>();

        internal MainForm(string rootPath)
        {
            root = rootPath;
            Text = "AgentOS Control Center";
            Width = 1120;
            Height = 720;
            MinimumSize = new Size(900, 560);
            StartPosition = FormStartPosition.CenterScreen;

            var toolbar = new FlowLayoutPanel { Dock = DockStyle.Top, Height = 44, Padding = new Padding(8), WrapContents = false };
            toolbar.Controls.Add(Button("Refresh", delegate { RefreshEvidence(); }));
            toolbar.Controls.Add(Button("Start", delegate { Control("start"); }));
            toolbar.Controls.Add(Button("Stop", delegate { Control("stop"); }));
            toolbar.Controls.Add(Button("Restart", delegate { Control("restart"); }));
            toolbar.Controls.Add(Button("Open log", delegate { OpenLog(); }));
            toolbar.Controls.Add(Button("Run CI", delegate { RunCi(); }));
            toolbar.Controls.Add(Button("Open CI report", delegate { OpenCiReport(); }));
            summary.AutoSize = true;
            summary.Padding = new Padding(16, 8, 0, 0);
            toolbar.Controls.Add(summary);

            grid.Dock = DockStyle.Fill;
            grid.ReadOnly = true;
            grid.AllowUserToAddRows = false;
            grid.AllowUserToDeleteRows = false;
            grid.AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill;
            grid.SelectionMode = DataGridViewSelectionMode.FullRowSelect;
            grid.MultiSelect = false;
            grid.Columns.Add("runtime_id", "Runtime ID");
            grid.Columns.Add("display_name", "Name");
            grid.Columns.Add("kind", "Kind");
            grid.Columns.Add("group", "Group");
            grid.Columns.Add("state", "State");
            grid.Columns.Add("scheduled", "Scheduled task");
            grid.Columns.Add("expected_identity", "Expected identity");
            grid.Columns.Add("identity", "Observed identity");
            grid.Columns.Add("pids", "PIDs");
            grid.Columns.Add("evidence", "Evidence");

            output.Dock = DockStyle.Bottom;
            output.Height = 150;
            output.Multiline = true;
            output.ReadOnly = true;
            output.ScrollBars = ScrollBars.Vertical;
            output.Font = new Font(FontFamily.GenericMonospace, 9f);

            Controls.Add(grid);
            Controls.Add(output);
            Controls.Add(toolbar);
            Shown += delegate { RefreshEvidence(); };
        }

        private static Button Button(string text, EventHandler action)
        {
            var button = new Button { Text = text, AutoSize = true, Height = 28 };
            button.Click += action;
            return button;
        }

        private string RunPowerShell(string script, IEnumerable<string> arguments)
        {
            var full = Path.GetFullPath(Path.Combine(root, script.Replace('/', Path.DirectorySeparatorChar)));
            if (!full.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase) || !File.Exists(full))
                throw new InvalidOperationException("Registered script is missing or outside AgentOS: " + script);
            var quotedArgs = string.Join(" ", arguments.Select(Quote));
            var start = new ProcessStartInfo("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File " + Quote(full) + " " + quotedArgs)
            {
                WorkingDirectory = root,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            using (var process = Process.Start(start))
            {
                var stdout = process.StandardOutput.ReadToEnd();
                var stderr = process.StandardError.ReadToEnd();
                process.WaitForExit();
                if (process.ExitCode != 0) throw new InvalidOperationException(stderr + Environment.NewLine + stdout);
                return stdout + stderr;
            }
        }

        private static string Quote(string value) { return "\"" + value.Replace("\"", "\\\"") + "\""; }

        private void RefreshEvidence()
        {
            try
            {
                output.Text = RunPowerShell("scripts/observability/collect-runtime-status.ps1", new[] { "-AgentOSRoot", root });
                LoadData();
            }
            catch (Exception ex) { ShowError(ex); }
        }

        private void LoadData()
        {
            var registry = (Dictionary<string, object>)json.DeserializeObject(File.ReadAllText(Path.Combine(root, "config", "runtime_registry.json")));
            var scriptRegistry = (Dictionary<string, object>)json.DeserializeObject(File.ReadAllText(Path.Combine(root, "config", "script_registry.json")));
            var status = (Dictionary<string, object>)json.DeserializeObject(File.ReadAllText(Path.Combine(root, "data", "observability", "runtime_status.json")));
            runtimes = ((object[])registry["runtimes"]).Cast<Dictionary<string, object>>().ToList();
            var statuses = ((object[])status["runtimes"]).Cast<Dictionary<string, object>>().ToDictionary(x => Convert.ToString(x["runtime_id"]));
            grid.Rows.Clear();
            foreach (var runtime in runtimes)
            {
                Dictionary<string, object> observed;
                statuses.TryGetValue(Convert.ToString(runtime["runtime_id"]), out observed);
                var pids = observed != null && observed.ContainsKey("pids") ? string.Join(",", ((object[])observed["pids"]).Select(Convert.ToString)) : "";
                var scheduled = "";
                if (observed != null && observed.ContainsKey("scheduled_tasks"))
                {
                    scheduled = string.Join(",", ((object[])observed["scheduled_tasks"]).Cast<Dictionary<string, object>>().Select(x => Convert.ToString(x["task_name"]) + ":" + Convert.ToString(x["state"])));
                }
                var enabled = Convert.ToBoolean(runtime["enabled"]);
                var kind = Convert.ToString(runtime["kind"]);
                var group = !enabled ? "retired / disabled" : kind == "per_event" ? "on-demand workflow" : kind == "scheduled" ? "maintenance" : "startup";
                grid.Rows.Add(runtime["runtime_id"], runtime["display_name"], kind, group, observed == null ? "unknown" : observed["state"], scheduled, runtime["expected_identity"], observed == null ? "" : observed["observed_identity"], pids, observed == null ? "" : observed["evidence_summary"]);
            }
            var scripts = ((object[])scriptRegistry["entries"]).Length;
            summary.Text = string.Format("{0} runtimes / {1} registered tools / evidence {2}", runtimes.Count, scripts, status["collected_at"]);
        }

        private Dictionary<string, object> SelectedRuntime()
        {
            if (grid.SelectedRows.Count != 1) throw new InvalidOperationException("Select one runtime first.");
            var id = Convert.ToString(grid.SelectedRows[0].Cells["runtime_id"].Value);
            return runtimes.Single(x => Convert.ToString(x["runtime_id"]) == id);
        }

        private void Control(string action)
        {
            try
            {
                var runtime = SelectedRuntime();
                if (!runtime.ContainsKey("control")) throw new InvalidOperationException("This runtime is read-only in the registry.");
                var control = (Dictionary<string, object>)runtime["control"];
                if (!Convert.ToBoolean(control["enabled"])) throw new InvalidOperationException("Control is disabled for this runtime.");
                if (MessageBox.Show(string.Format("{0} {1}?", action, runtime["display_name"]), "Confirm", MessageBoxButtons.OKCancel, MessageBoxIcon.Warning) != DialogResult.OK) return;
                var arguments = new List<string> { "-RuntimeId", Convert.ToString(runtime["runtime_id"]), "-Action", action, "-AgentOSRoot", root };
                if (control.ContainsKey("requires_dispatch_id") && Convert.ToBoolean(control["requires_dispatch_id"]))
                {
                    var dispatchId = Microsoft.VisualBasic.Interaction.InputBox("Root dispatch ID", "Queue control", "");
                    if (string.IsNullOrWhiteSpace(dispatchId)) return;
                    arguments.Add("-DispatchId");
                    arguments.Add(dispatchId);
                }
                output.Text = RunPowerShell("scripts/runtimes/control-runtime.ps1", arguments);
                RefreshEvidence();
            }
            catch (Exception ex) { ShowError(ex); }
        }

        private void OpenLog()
        {
            try
            {
                var runtime = SelectedRuntime();
                var logs = (object[])runtime["log_paths"];
                if (logs.Length == 0) throw new InvalidOperationException("No log is registered for this runtime.");
                var path = Path.GetFullPath(Path.Combine(root, Convert.ToString(logs[0]).Replace('/', Path.DirectorySeparatorChar)));
                if (!File.Exists(path)) throw new FileNotFoundException("Registered log does not exist.", path);
                Process.Start("notepad.exe", Quote(path));
            }
            catch (Exception ex) { ShowError(ex); }
        }

        private void RunCi()
        {
            try { output.Text = RunPowerShell("scripts/entrypoints/agentos-check.ps1", new string[0]); }
            catch (Exception ex) { ShowError(ex); }
        }

        private void OpenCiReport()
        {
            try
            {
                var path = Path.Combine(root, "data", "ci_health", "latest.md");
                if (!File.Exists(path)) throw new FileNotFoundException("No CI report exists yet. Run CI first.", path);
                Process.Start("notepad.exe", Quote(path));
            }
            catch (Exception ex) { ShowError(ex); }
        }

        private void ShowError(Exception ex)
        {
            output.Text = ex.ToString();
            MessageBox.Show(ex.Message, "AgentOS Control Center", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
    }
}
