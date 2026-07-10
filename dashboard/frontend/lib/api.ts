const BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

async function readJson(res: Response) {
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json();
}

export async function fetchUsage() {
  const res = await fetch(`${BASE}/api/usage`);
  return readJson(res);
}

export async function fetchRuntimes() {
  const res = await fetch(`${BASE}/api/runtimes`, { cache: "no-store" });
  return readJson(res);
}

export async function fetchRuntimeEvents(runtimeId?: string) {
  const query = runtimeId ? `?runtime_id=${encodeURIComponent(runtimeId)}` : "";
  const res = await fetch(`${BASE}/api/events${query}`, { cache: "no-store" });
  return readJson(res);
}

export async function fetchGovernance() {
  const res = await fetch(`${BASE}/api/governance`, { cache: "no-store" });
  return res.json();
}

export async function fetchBridgeSessions() {
  const res = await fetch(`${BASE}/api/bridge`);
  return res.json();
}

export async function fetchBridgeSession(id: string) {
  const res = await fetch(`${BASE}/api/bridge/${id}`);
  return res.json();
}

export async function fetchTasks() {
  const res = await fetch(`${BASE}/api/tasks`);
  return res.json();
}

export async function fetchTask(id: string) {
  const res = await fetch(`${BASE}/api/tasks/${id}`);
  return res.json();
}

export async function fetchWorkflows() {
  const res = await fetch(`${BASE}/api/workflows`, { cache: "no-store" });
  return res.json();
}

export async function controlWorkflow(id: string, action: "pause" | "resume" | "retry") {
  const res = await fetch(`${BASE}/api/workflows/${encodeURIComponent(id)}/control`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ action }),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export async function fetchApprovals() {
  const res = await fetch(`${BASE}/api/approvals`, { cache: "no-store" });
  return res.json();
}

export async function decideApproval(
  id: string,
  decision: "approve" | "modify" | "stop",
  note = "",
) {
  const res = await fetch(`${BASE}/api/approvals/${encodeURIComponent(id)}/decision`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ decision, note }),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export async function fetchLeads() {
  const res = await fetch(`${BASE}/api/leads`);
  return res.json();
}

export async function fetchLogs() {
  const res = await fetch(`${BASE}/api/logs`);
  return res.json();
}

export function wsUrl(path: string) {
  const base = BASE.replace(/^http/, "ws");
  return `${base}${path}`;
}
