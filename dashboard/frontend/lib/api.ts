const BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";
const CSRF_KEY = "agentos-dashboard-csrf";

async function apiFetch(input: RequestInfo | URL, init: RequestInit = {}) {
  const method = (init.method ?? "GET").toUpperCase();
  const headers = new Headers(init.headers);
  if (!["GET", "HEAD", "OPTIONS"].includes(method) && typeof window !== "undefined") {
    const csrf = window.sessionStorage.getItem(CSRF_KEY);
    if (csrf) headers.set("X-CSRF-Token", csrf);
    headers.set("X-Request-ID", crypto.randomUUID());
  }
  return fetch(input, { ...init, headers, credentials: "include" });
}

async function readJson(res: Response) {
  if (!res.ok) {
    let detail = "";
    try {
      const payload = await res.json();
      detail = typeof payload.detail === "string" ? payload.detail : "";
    } catch {
      detail = await res.text().catch(() => "");
    }
    throw new Error(detail || `${res.status} ${res.statusText}`);
  }
  return res.json();
}

export async function fetchUsage() {
  const res = await apiFetch(`${BASE}/api/usage`);
  return readJson(res);
}

export async function fetchContext() {
  const res = await apiFetch(`${BASE}/api/context`, { cache: "no-store" });
  return readJson(res);
}

export async function fetchRuntimes() {
  const res = await apiFetch(`${BASE}/api/runtimes`, { cache: "no-store" });
  return readJson(res);
}

export async function fetchRuntimeHistory(limit = 48) {
  const res = await apiFetch(`${BASE}/api/runtime-history?limit=${limit}`, { cache: "no-store" });
  return readJson(res);
}

export async function fetchRuntimeEvents(runtimeId?: string, dispatchId?: string) {
  const params = new URLSearchParams();
  if (runtimeId) params.set("runtime_id", runtimeId);
  if (dispatchId) params.set("dispatch_id", dispatchId);
  const query = params.size ? `?${params.toString()}` : "";
  const res = await apiFetch(`${BASE}/api/events${query}`, { cache: "no-store" });
  return readJson(res);
}

export async function fetchFailures() {
  const res = await apiFetch(`${BASE}/api/failures`, { cache: "no-store" });
  return readJson(res);
}

export async function askStatus(question: string) {
  const res = await apiFetch(`${BASE}/api/status-assistant?q=${encodeURIComponent(question)}`, { cache: "no-store" });
  return readJson(res);
}

export async function fetchGovernance() {
  const res = await apiFetch(`${BASE}/api/governance`, { cache: "no-store" });
  return res.json();
}

export async function fetchBridgeSessions() {
  const res = await apiFetch(`${BASE}/api/bridge`);
  return res.json();
}

export async function fetchBridgeSession(id: string) {
  const res = await apiFetch(`${BASE}/api/bridge/${id}`);
  return res.json();
}

export async function fetchTasks() {
  const res = await apiFetch(`${BASE}/api/tasks`);
  return res.json();
}

export async function fetchTask(id: string) {
  const res = await apiFetch(`${BASE}/api/tasks/${id}`);
  return res.json();
}

export async function fetchWorkflows() {
  const res = await apiFetch(`${BASE}/api/workflows`, { cache: "no-store" });
  return res.json();
}

export async function controlWorkflow(id: string, action: "pause" | "resume" | "retry") {
  const res = await apiFetch(`${BASE}/api/workflows/${encodeURIComponent(id)}/control`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ action }),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export async function fetchApprovals() {
  const res = await apiFetch(`${BASE}/api/approvals`, { cache: "no-store" });
  return res.json();
}

export async function decideApproval(
  id: string,
  decision: "approve" | "modify" | "stop",
  note = "",
) {
  const res = await apiFetch(`${BASE}/api/approvals/${encodeURIComponent(id)}/decision`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ decision, note }),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export async function fetchDecisions() {
  const res = await apiFetch(`${BASE}/api/decisions`, { cache: "no-store" });
  return readJson(res);
}

export async function createDecision(payload: { title: string; status: string; body: string; links: string[] }) {
  const res = await apiFetch(`${BASE}/api/decisions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export async function setDecisionStatus(id: string, status: string, evidence = "") {
  const res = await apiFetch(`${BASE}/api/decisions/${encodeURIComponent(id)}/status`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ status, evidence }),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export async function addDecisionLink(id: string, target: string) {
  const res = await apiFetch(`${BASE}/api/decisions/${encodeURIComponent(id)}/links`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ target }),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export async function saveDecisionLayout(positions: Record<string, { x: number; y: number }>) {
  const res = await apiFetch(`${BASE}/api/decisions/layout`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ positions }),
  });
  if (!res.ok) throw new Error(await res.text());
  return res.json();
}

export async function fetchLeads() {
  const res = await apiFetch(`${BASE}/api/leads`);
  return res.json();
}

export async function fetchLogs() {
  const res = await apiFetch(`${BASE}/api/logs`);
  return res.json();
}

export function wsUrl(path: string) {
  const base = BASE.replace(/^http/, "ws");
  return `${base}${path}`;
}

export async function fetchAuthStatus() {
  const res = await apiFetch(`${BASE}/api/auth/status`, { cache: "no-store" });
  const data = await readJson(res);
  if (data.authenticated && data.csrf_token && typeof window !== "undefined") {
    window.sessionStorage.setItem(CSRF_KEY, data.csrf_token);
  }
  return data;
}

export async function loginOwner(token: string) {
  const res = await apiFetch(`${BASE}/api/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token }),
  });
  const data = await readJson(res);
  if (data.csrf_token && typeof window !== "undefined") {
    window.sessionStorage.setItem(CSRF_KEY, data.csrf_token);
  }
  return data;
}

export async function logoutOwner() {
  const res = await apiFetch(`${BASE}/api/auth/logout`, { method: "POST" });
  if (typeof window !== "undefined") window.sessionStorage.removeItem(CSRF_KEY);
  return readJson(res);
}

export async function fetchToday() {
  return readJson(await apiFetch(`${BASE}/api/v1/today`, { cache: "no-store" }));
}

export async function searchKnowledge(query = "") {
  const url = query
    ? `${BASE}/api/v1/knowledge/search?q=${encodeURIComponent(query)}`
    : `${BASE}/api/v1/knowledge`;
  return readJson(await apiFetch(url, { cache: "no-store" }));
}

export async function fetchKnowledgeNode(id: string) {
  return readJson(await apiFetch(`${BASE}/api/v1/knowledge/${encodeURIComponent(id)}`, { cache: "no-store" }));
}

export async function fetchKnowledgeArtifact(ref: string) {
  return readJson(await apiFetch(`${BASE}/api/v1/knowledge/artifacts/${encodeURIComponent(ref)}`, { cache: "no-store" }));
}

export async function addKnowledgeFeedback(id: string, content: string, target = "") {
  return readJson(await apiFetch(`${BASE}/api/v1/knowledge/${encodeURIComponent(id)}/feedback`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content, target }),
  }));
}

export async function createKnowledgeDiscussion(id: string, content: string) {
  return readJson(await apiFetch(`${BASE}/api/v1/knowledge/${encodeURIComponent(id)}/discussions`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content }),
  }));
}

export async function addKnowledgeMessage(id: string, discussionId: string, content: string) {
  return readJson(await apiFetch(`${BASE}/api/v1/knowledge/${encodeURIComponent(id)}/discussions/${encodeURIComponent(discussionId)}/messages`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ content }),
  }));
}

export async function exportKnowledgeCandidate(id: string, discussionId: string, title: string, summary: string) {
  return readJson(await apiFetch(`${BASE}/api/v1/knowledge/${encodeURIComponent(id)}/candidate`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ discussion_id: discussionId, title, summary }),
  }));
}
