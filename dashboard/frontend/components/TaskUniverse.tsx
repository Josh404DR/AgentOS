"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  Handle,
  Position,
  Node,
  Edge,
  NodeProps,
} from "@xyflow/react";
import { Search, RefreshCw, X, ExternalLink } from "lucide-react";
import { fetchTask, fetchTasks } from "@/lib/api";

type TaskStatus = "ready" | "processing" | "completed" | "blocked";

interface Task {
  id: string;
  dispatch_id: string;
  title: string;
  normalized_status: TaskStatus;
  route_to: string;
  dispatch_status?: string;
  task_status?: string;
  governance_version: string;
  review_status?: string;
  pending_approval: boolean;
  failure_reason?: string;
  models_invoked?: string;
  external_actions_invoked?: string;
  has_result: boolean;
  result_preview: string;
  artifact_path: string;
  result_path?: string;
  evidence_files: string[];
  obsidian_path: string;
  obsidian_uri: string;
  mtime: number;
  mtime_str: string;
}

interface TaskDetail {
  id: string;
  files: Record<string, string>;
}

interface UniverseNodeData extends Record<string, unknown> {
  label: string;
  sub: string;
  status: TaskStatus | "core";
  task?: Task;
  onSelect?: (task: Task) => void;
}

const statusZh: Record<TaskStatus, string> = {
  ready: "等待中",
  processing: "進行中",
  completed: "已完成",
  blocked: "受阻",
};

function signal(value: string | boolean | undefined): string {
  if (value === true) return "true";
  if (value === false) return "false";
  return value || "未標示";
}

const statusStyle: Record<TaskStatus | "core", string> = {
  core: "border-purple-400 bg-purple-950 text-purple-100 shadow-purple-800/50",
  ready: "border-sky-500 bg-sky-950 text-sky-100 shadow-sky-900/40",
  processing: "border-amber-400 bg-amber-950 text-amber-100 shadow-amber-700/60 task-node-processing",
  completed: "border-emerald-500 bg-emerald-950 text-emerald-100 shadow-emerald-900/40",
  blocked: "border-red-500 bg-red-950 text-red-100 shadow-red-900/50",
};

function UniverseNode({ data, selected }: NodeProps<Node<UniverseNodeData>>) {
  return (
    <button
      type="button"
      onClick={(event) => {
        event.stopPropagation();
        if (data.task && data.onSelect) data.onSelect(data.task);
      }}
      className={`nodrag nopan min-w-44 max-w-56 rounded-full border px-4 py-3 text-left shadow-xl transition ${statusStyle[data.status]} ${selected ? "ring-2 ring-white" : ""}`}
      aria-label={data.task ? `開啟工單 ${data.task.dispatch_id}` : data.label}
    >
      <Handle type="target" position={Position.Top} className="!h-2 !w-2 !bg-zinc-500" />
      <p className="truncate text-[11px] font-semibold">{data.label}</p>
      <p className="mt-0.5 truncate text-[9px] opacity-70">{data.sub}</p>
      <Handle type="source" position={Position.Bottom} className="!h-2 !w-2 !bg-zinc-500" />
    </button>
  );
}

const nodeTypes = { universe: UniverseNode };

function resultText(detail: TaskDetail | null): string {
  if (!detail) return "尚未載入工單內容。";
  const result = detail.files["OUTPUTS\\RESULT.md"] ?? detail.files["OUTPUTS/RESULT.md"];
  if (result) return result;
  const status = detail.files["OUTPUTS\\WORKER_STATUS.md"] ?? detail.files["OUTPUTS/WORKER_STATUS.md"];
  if (status) return status;
  return detail.files["TASK.md"] ?? "此工單尚未產生結果。";
}

export default function TaskUniverse() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [query, setQuery] = useState("");
  const [selected, setSelected] = useState<Task | null>(null);
  const [detail, setDetail] = useState<TaskDetail | null>(null);
  const [loading, setLoading] = useState(false);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const incoming = await fetchTasks();
      setTasks(Array.isArray(incoming) ? incoming : []);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const initial = window.setTimeout(() => void refresh(), 0);
    const timer = window.setInterval(() => void refresh(), 5000);
    return () => {
      window.clearTimeout(initial);
      window.clearInterval(timer);
    };
  }, [refresh]);

  useEffect(() => {
    if (!selected) {
      const resetTimer = window.setTimeout(() => setDetail(null), 0);
      return () => window.clearTimeout(resetTimer);
    }
    fetchTask(selected.id).then(setDetail).catch(() => setDetail(null));
  }, [selected]);

  const visibleTasks = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    const filtered = normalized
      ? tasks.filter((task) =>
          task.id.toLowerCase().includes(normalized) ||
          task.dispatch_id.toLowerCase().includes(normalized) ||
          task.title.toLowerCase().includes(normalized))
      : tasks;
    return filtered.slice(0, 36);
  }, [tasks, query]);

  const nodes = useMemo<Node<UniverseNodeData>[]>(() => {
    const centerX = 560;
    const centerY = 360;
    const output: Node<UniverseNodeData>[] = [{
      id: "governance-core",
      type: "universe",
      position: { x: centerX, y: centerY },
      data: { label: "AgentOS 共同治理", sub: "v1.1.0 · 工單軌道中心", status: "core" },
    }];
    visibleTasks.forEach((task, index) => {
      const ring = Math.floor(index / 12);
      const slot = index % 12;
      const radius = 250 + ring * 210;
      const angle = (slot / 12) * Math.PI * 2 - Math.PI / 2 + ring * 0.18;
      output.push({
        id: task.id,
        type: "universe",
        position: {
          x: centerX + Math.cos(angle) * radius,
          y: centerY + Math.sin(angle) * radius,
        },
        data: {
          label: task.dispatch_id,
          sub: `${statusZh[task.normalized_status]} · ${task.route_to}${task.review_status ? ` · review:${task.review_status}` : ""}`,
          status: task.normalized_status,
          task,
          onSelect: setSelected,
        },
      });
    });
    return output;
  }, [visibleTasks]);

  const edges = useMemo<Edge[]>(() =>
    visibleTasks.map((task) => ({
      id: `orbit-${task.id}`,
      source: "governance-core",
      target: task.id,
      animated: task.normalized_status === "processing",
      style: {
        stroke: task.normalized_status === "blocked" ? "#ef4444" :
          task.normalized_status === "completed" ? "#10b981" :
          task.normalized_status === "processing" ? "#f59e0b" : "#3b82f6",
        strokeDasharray: task.normalized_status === "ready" ? "4,5" : undefined,
        opacity: 0.65,
      },
    })), [visibleTasks]);

  const onNodeClick = useCallback((_: unknown, node: Node<UniverseNodeData>) => {
    if (node.data.task) setSelected(node.data.task);
  }, []);

  return (
    <div className="flex h-full bg-zinc-950">
      <section className="relative min-w-0 flex-1">
        <div className="absolute left-4 top-4 z-10">
          <div className="flex items-center gap-2 rounded-xl border border-zinc-700 bg-zinc-900/90 p-2 backdrop-blur">
            <Search size={14} className="text-zinc-400" />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="輸入工單號、dispatch_id 或標題"
              className="w-80 bg-transparent text-xs text-zinc-100 outline-none placeholder:text-zinc-600"
            />
            {query && <button onClick={() => setQuery("")} title="清除搜尋"><X size={13} /></button>}
            <button onClick={refresh} title="重新整理"><RefreshCw size={13} className={loading ? "animate-spin" : ""} /></button>
            <span className="text-[10px] text-zinc-500">顯示 {visibleTasks.length}/{tasks.length}</span>
          </div>
          {query && (
            <div className="mt-1 max-h-56 w-[520px] overflow-auto rounded-xl border border-zinc-700 bg-zinc-950/95 p-1 shadow-2xl">
              {visibleTasks.slice(0, 8).map((task) => (
                <button
                  key={task.id}
                  type="button"
                  onClick={() => setSelected(task)}
                  className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-left hover:bg-zinc-800"
                  aria-label={`查看工單 ${task.dispatch_id}`}
                >
                  <span className={`h-2 w-2 rounded-full border ${statusStyle[task.normalized_status]}`} />
                  <span className="min-w-0 flex-1 truncate font-mono text-[10px] text-zinc-200">{task.dispatch_id}</span>
                  <span className="text-[9px] text-zinc-500">{statusZh[task.normalized_status]}</span>
                </button>
              ))}
              {!visibleTasks.length && <p className="px-3 py-2 text-[10px] text-zinc-500">找不到符合的工單。</p>}
            </div>
          )}
        </div>

        <ReactFlow
          nodes={nodes}
          edges={edges}
          nodeTypes={nodeTypes}
          onNodeClick={onNodeClick}
          fitView
          fitViewOptions={{ padding: 0.25 }}
          minZoom={0.15}
          maxZoom={1.8}
          className="bg-[radial-gradient(circle_at_center,_#18112d_0,_#09090b_45%,_#020204_100%)]"
        >
          <Background color="#312e81" gap={32} size={1} />
          <Controls className="[&>button]:border-zinc-700 [&>button]:bg-zinc-800 [&>button]:text-zinc-200" />
          <MiniMap className="!border-zinc-700 !bg-zinc-900" pannable zoomable />
        </ReactFlow>

        <div className="absolute bottom-4 left-4 z-10 flex gap-3 rounded-lg border border-zinc-800 bg-zinc-900/90 px-3 py-2 text-[9px]">
          {Object.entries(statusZh).map(([key, value]) => (
            <span key={key} className="flex items-center gap-1 text-zinc-400">
              <i className={`h-2 w-2 rounded-full border ${statusStyle[key as TaskStatus]}`} />{value}
            </span>
          ))}
        </div>
      </section>

      <aside className={`border-l border-zinc-800 bg-zinc-900 transition-all ${selected ? "w-[420px]" : "w-0"} overflow-hidden`}>
        {selected && (
          <div className="flex h-full flex-col">
            <header className="border-b border-zinc-800 p-4">
              <div className="flex items-start gap-2">
                <div className="min-w-0 flex-1">
                  <p className="text-[10px] text-zinc-500">工單號</p>
                  <p className="break-all font-mono text-xs text-zinc-200">{selected.dispatch_id}</p>
                </div>
                <button onClick={() => setSelected(null)}><X size={15} /></button>
              </div>
              <h2 className="mt-3 text-sm font-semibold text-zinc-100">{selected.title}</h2>
              <div className="mt-3 grid grid-cols-2 gap-2 text-[10px]">
                <p className="rounded bg-zinc-800 p-2">狀態：{statusZh[selected.normalized_status]}</p>
                <p className="rounded bg-zinc-800 p-2">路由：{selected.route_to}</p>
                <p className="rounded bg-zinc-800 p-2">治理：{selected.governance_version}</p>
                <p className="rounded bg-zinc-800 p-2">更新：{selected.mtime_str}</p>
                <p className="rounded bg-zinc-800 p-2">review：{signal(selected.review_status)}</p>
                <p className="rounded bg-zinc-800 p-2">待核准：{signal(selected.pending_approval)}</p>
                <p className="rounded bg-zinc-800 p-2">models：{signal(selected.models_invoked)}</p>
                <p className="rounded bg-zinc-800 p-2">external：{signal(selected.external_actions_invoked)}</p>
              </div>
              {selected.failure_reason && (
                <p className="mt-3 rounded border border-red-900 bg-red-950/40 p-2 text-[10px] text-red-200">
                  {selected.failure_reason}
                </p>
              )}
              <div className="mt-3 space-y-1 rounded border border-zinc-800 bg-black/30 p-2 text-[9px] text-zinc-500">
                <p className="break-all font-mono">artifact: {selected.artifact_path}</p>
                {selected.result_path && <p className="break-all font-mono">result: {selected.result_path}</p>}
                <p>evidence: {selected.evidence_files.join(", ") || "none"}</p>
              </div>
              <a
                href={selected.obsidian_uri}
                className="mt-3 flex items-center justify-center gap-2 rounded-lg border border-purple-700 bg-purple-950 px-3 py-2 text-[11px] text-purple-200 hover:bg-purple-900"
                title={selected.obsidian_path}
              >
                <ExternalLink size={13} />
                在 Obsidian 開啟此工單
              </a>
            </header>
            <div className="min-h-0 flex-1 overflow-auto p-4">
              <h3 className="mb-2 text-xs font-semibold text-zinc-300">進度與實際變更</h3>
              <pre className="whitespace-pre-wrap break-words rounded-lg border border-zinc-800 bg-black/50 p-3 text-[11px] leading-relaxed text-zinc-300">
                {resultText(detail)}
              </pre>
            </div>
          </div>
        )}
      </aside>
    </div>
  );
}
