"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  CheckCircle2,
  Circle,
  Clock3,
  Pause,
  Play,
  RefreshCw,
  RotateCcw,
  Search,
  ShieldCheck,
} from "lucide-react";
import { controlWorkflow, fetchWorkflows } from "@/lib/api";

type StageState = "completed" | "processing" | "blocked" | "pending" | "skipped";

interface Stage {
  key: string;
  label: string;
  state: StageState;
}

interface Workflow {
  dispatch_id: string;
  title: string;
  task_type: string;
  supervisor_status: string;
  current_stage: string;
  latest_verdict: string;
  node_count: number;
  pending_worker_count: number;
  pending_verify_count: number;
  escalation_count: number;
  failure_reason: string;
  result_path: string;
  control_state: string;
  last_control_action: string;
  last_control_at: string;
  queue_status: string;
  queue_process_id: number | null;
  queue_process_alive: boolean;
  queue_detail: string;
  last_queue_event: string;
  updated_at: number;
  stages: Stage[];
  nodes: Array<{
    dispatch_id: string;
    route_to: string;
    status: string;
    review_status: string;
    result_path: string;
  }>;
}

const statusLabel: Record<string, string> = {
  completed: "已完成",
  processing: "執行中",
  verifying: "等待驗證",
  planned: "已規劃",
  queued: "等待排程",
  blocked: "受阻",
  waiting_josh: "等待 Josh",
  step_completed: "單一步驟完成",
};

const statusClass: Record<string, string> = {
  completed: "border-emerald-500/60 bg-emerald-950/50 text-emerald-200",
  processing: "border-amber-500/60 bg-amber-950/50 text-amber-200",
  verifying: "border-purple-500/60 bg-purple-950/50 text-purple-200",
  planned: "border-sky-500/60 bg-sky-950/50 text-sky-200",
  queued: "border-zinc-600 bg-zinc-900 text-zinc-300",
  blocked: "border-red-500/60 bg-red-950/50 text-red-200",
  waiting_josh: "border-orange-500/60 bg-orange-950/50 text-orange-200",
  step_completed: "border-cyan-500/60 bg-cyan-950/50 text-cyan-200",
};

const stageClass: Record<StageState, string> = {
  completed: "border-emerald-500 bg-emerald-500 text-zinc-950",
  processing: "border-amber-400 bg-amber-400 text-zinc-950 animate-pulse",
  blocked: "border-red-500 bg-red-500 text-white",
  pending: "border-zinc-600 bg-zinc-900 text-zinc-500",
  skipped: "border-zinc-800 bg-zinc-950 text-zinc-700",
};

function StageIcon({ state }: { state: StageState }) {
  if (state === "completed") return <CheckCircle2 size={14} />;
  if (state === "processing") return <Clock3 size={14} />;
  if (state === "blocked") return <AlertTriangle size={14} />;
  return <Circle size={12} />;
}

export default function WorkflowSupervisor() {
  const [workflows, setWorkflows] = useState<Workflow[]>([]);
  const [query, setQuery] = useState("telegram-telegram-1449022024-");
  const [selected, setSelected] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState("");
  const [feedback, setFeedback] = useState<Record<string, string>>({});

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const response = await fetchWorkflows();
      setWorkflows(Array.isArray(response) ? response : []);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const initial = window.setTimeout(refresh, 0);
    const timer = window.setInterval(refresh, 5000);
    return () => {
      window.clearTimeout(initial);
      window.clearInterval(timer);
    };
  }, [refresh]);

  const visible = useMemo(() => {
    const value = query.trim().toLowerCase();
    return workflows
      .filter((workflow) =>
        !value ||
        workflow.dispatch_id.toLowerCase().includes(value) ||
        workflow.title.toLowerCase().includes(value))
      .slice(0, 12);
  }, [query, workflows]);

  const summary = useMemo(() => ({
    completed: visible.filter((item) => item.supervisor_status === "completed").length,
    active: visible.filter((item) =>
      ["processing", "verifying"].includes(item.supervisor_status)).length,
    blocked: visible.filter((item) =>
      ["blocked", "waiting_josh"].includes(item.supervisor_status)).length,
  }), [visible]);

  const control = async (
    workflow: Workflow,
    action: "pause" | "resume" | "retry",
  ) => {
    const labels = { pause: "暫停", resume: "繼續", retry: "重新執行未完成步驟" };
    if (!window.confirm(`${labels[action]}工單 ${workflow.dispatch_id}？`)) return;
    setBusy(workflow.dispatch_id);
    setFeedback((current) => ({
      ...current,
      [workflow.dispatch_id]: `${labels[action]}要求送出中…`,
    }));
    try {
      const response = await controlWorkflow(workflow.dispatch_id, action);
      setFeedback((current) => ({
        ...current,
        [workflow.dispatch_id]: response.message || "控制要求已接受。",
      }));
      await refresh();
    } catch (error) {
      setFeedback((current) => ({
        ...current,
        [workflow.dispatch_id]: error instanceof Error ? error.message : "控制要求失敗。",
      }));
    } finally {
      setBusy("");
    }
  };

  return (
    <div className="flex h-full flex-col overflow-hidden bg-zinc-950">
      <header className="flex items-center gap-3 border-b border-zinc-800 px-5 py-3">
        <ShieldCheck size={18} className="text-purple-300" />
        <div>
          <h2 className="text-sm font-semibold">Hermes Workflow Supervisor</h2>
          <p className="text-[10px] text-zinc-500">
            只有最終 Verify PASS、無未解 escalation 才能關帳
          </p>
        </div>
        <div className="ml-4 flex gap-2 text-[10px]">
          <span className="rounded bg-emerald-950 px-2 py-1 text-emerald-300">完成 {summary.completed}</span>
          <span className="rounded bg-amber-950 px-2 py-1 text-amber-300">進行 {summary.active}</span>
          <span className="rounded bg-red-950 px-2 py-1 text-red-300">受阻 {summary.blocked}</span>
        </div>
        <div className="ml-auto flex items-center gap-2 rounded-lg border border-zinc-800 bg-zinc-900 px-3 py-2">
          <Search size={13} className="text-zinc-500" />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            className="w-72 bg-transparent text-xs outline-none"
            placeholder="搜尋工單號或標題"
          />
          <button onClick={refresh} title="重新整理">
            <RefreshCw size={13} className={loading ? "animate-spin" : ""} />
          </button>
        </div>
      </header>

      <div className="min-h-0 flex-1 overflow-auto p-5">
        <div className="space-y-3">
          {visible.map((workflow) => {
            const open = selected === workflow.dispatch_id;
            return (
              <article
                key={workflow.dispatch_id}
                className={`rounded-xl border p-4 ${statusClass[workflow.supervisor_status] ?? statusClass.queued}`}
              >
                <button
                  type="button"
                  className="w-full text-left"
                  onClick={() => setSelected(open ? null : workflow.dispatch_id)}
                >
                  <div className="flex items-start gap-3">
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-mono text-[11px]">{workflow.dispatch_id}</p>
                      <p className="mt-1 truncate text-xs font-semibold">{workflow.title}</p>
                    </div>
                    <div className="text-right">
                      <p className="text-xs font-bold">
                        {statusLabel[workflow.supervisor_status] ?? workflow.supervisor_status}
                      </p>
                      <p className="text-[9px] opacity-70">目前：{workflow.current_stage}</p>
                      <p className={`mt-1 inline-flex items-center gap-1 rounded px-2 py-0.5 text-[9px] ${
                        workflow.queue_process_alive
                          ? "bg-emerald-900 text-emerald-200"
                          : workflow.queue_status === "blocked"
                            ? "bg-red-900 text-red-200"
                            : "bg-zinc-800 text-zinc-400"
                      }`}>
                        <i className={`h-1.5 w-1.5 rounded-full ${
                          workflow.queue_process_alive ? "animate-pulse bg-emerald-400" :
                          workflow.queue_status === "blocked" ? "bg-red-400" : "bg-zinc-500"
                        }`} />
                        {workflow.queue_process_alive
                          ? `Queue 執行中 · PID ${workflow.queue_process_id}`
                          : workflow.queue_status === "blocked"
                            ? `Queue 受阻 · ${workflow.queue_detail || "原因未標示"}`
                            : workflow.queue_status === "completed"
                              ? "Queue 已結束"
                              : "Queue 尚未啟動"}
                      </p>
                    </div>
                  </div>

                  <div className="mt-4 flex items-center">
                    {workflow.stages.map((stage, index) => (
                      <div key={stage.key} className="flex min-w-0 flex-1 items-center">
                        <div className="flex min-w-20 flex-col items-center">
                          <span className={`flex h-7 w-7 items-center justify-center rounded-full border ${stageClass[stage.state]}`}>
                            <StageIcon state={stage.state} />
                          </span>
                          <span className="mt-1 text-[9px] opacity-80">{stage.label}</span>
                        </div>
                        {index < workflow.stages.length - 1 && (
                          <span className={`h-px flex-1 ${
                            stage.state === "completed" ? "bg-emerald-500" :
                            stage.state === "blocked" ? "bg-red-500" : "bg-zinc-700"
                          }`} />
                        )}
                      </div>
                    ))}
                  </div>
                </button>

                <div className="mt-3 flex justify-end gap-2 border-t border-current/20 pt-3">
                  <div className="mr-auto min-w-0 text-[9px]">
                    {feedback[workflow.dispatch_id] && (
                      <p className="font-semibold text-sky-200">{feedback[workflow.dispatch_id]}</p>
                    )}
                    {workflow.last_control_at && (
                      <p className="text-zinc-500">
                        最近控制：{workflow.last_control_action || workflow.control_state} · {workflow.last_control_at}
                      </p>
                    )}
                    {workflow.last_queue_event && (
                      <p className="max-w-xl truncate font-mono text-zinc-500" title={workflow.last_queue_event}>
                        最後事件：{workflow.last_queue_event}
                      </p>
                    )}
                  </div>
                  <button
                    disabled={busy === workflow.dispatch_id}
                    onClick={() => control(workflow, "pause")}
                    className="flex items-center gap-1 rounded border border-zinc-600 bg-zinc-900/70 px-2 py-1 text-[10px] disabled:opacity-50"
                  >
                    <Pause size={11} />暫停
                  </button>
                  <button
                    disabled={busy === workflow.dispatch_id}
                    onClick={() => control(workflow, "resume")}
                    className="flex items-center gap-1 rounded border border-emerald-700 bg-emerald-950/70 px-2 py-1 text-[10px] disabled:opacity-50"
                  >
                    <Play size={11} />繼續
                  </button>
                  <button
                    disabled={busy === workflow.dispatch_id}
                    onClick={() => control(workflow, "retry")}
                    className="flex items-center gap-1 rounded border border-sky-700 bg-sky-950/70 px-2 py-1 text-[10px] disabled:opacity-50"
                  >
                    <RotateCcw size={11} />重跑未完成
                  </button>
                </div>

                {open && (
                  <div className="mt-4 grid gap-3 border-t border-current/20 pt-4 lg:grid-cols-2">
                    <div className="space-y-1 text-[10px]">
                      <p>節點數：{workflow.node_count}</p>
                      <p>待實作：{workflow.pending_worker_count}</p>
                      <p>待驗證：{workflow.pending_verify_count}</p>
                      <p>未解 escalation：{workflow.escalation_count}</p>
                      <p>最新 verdict：{workflow.latest_verdict || "尚無"}</p>
                      {workflow.failure_reason && (
                        <p className="rounded bg-black/30 p-2 text-red-200">{workflow.failure_reason}</p>
                      )}
                    </div>
                    <div className="max-h-36 overflow-auto rounded bg-black/30 p-2 font-mono text-[9px]">
                      {workflow.nodes.map((node) => (
                        <p key={node.dispatch_id} className="border-b border-zinc-800 py-1 last:border-0">
                          {node.status.padEnd(10)} · {node.route_to.padEnd(8)} · {node.dispatch_id}
                          {node.review_status ? ` · ${node.review_status}` : ""}
                        </p>
                      ))}
                    </div>
                  </div>
                )}
              </article>
            );
          })}
        </div>
      </div>
    </div>
  );
}
