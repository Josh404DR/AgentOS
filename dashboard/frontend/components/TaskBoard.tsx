"use client";

import { useEffect, useMemo, useState } from "react";
import { fetchTasks, fetchTask } from "@/lib/api";
import {
  AlertTriangle,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  ClipboardList,
  FileText,
  LockKeyhole,
  ShieldQuestion,
} from "lucide-react";

type NormalizedStatus = "ready" | "processing" | "completed" | "blocked";

interface Task {
  id: string;
  title: string;
  purpose: string;
  status: string;
  normalized_status: NormalizedStatus;
  dispatch_id: string;
  route_to: string;
  assigned_to?: string;
  parent_dispatch_id?: string;
  source_dispatch_id?: string;
  dispatch_status?: string;
  task_status?: string;
  governance_version: string;
  workflow_version?: string;
  task_type?: string;
  risk_hits?: string;
  escalation_status?: string;
  review_status?: string;
  has_review_flow_status: boolean;
  has_claude_review: boolean;
  requires_josh_approval?: boolean;
  approval?: string;
  pending_approval: boolean;
  models_invoked?: string;
  external_actions_invoked?: string;
  cleanup_executed?: string;
  failure_reason?: string;
  artifact_path: string;
  result_path?: string;
  evidence_files: string[];
  mtime: number;
  mtime_str: string;
}

interface TaskDetail {
  id: string;
  files: Record<string, string>;
}

const statusLabel: Record<NormalizedStatus, string> = {
  ready: "等待中",
  processing: "進行中",
  completed: "已完成",
  blocked: "受阻",
};

const statusColor: Record<NormalizedStatus, string> = {
  ready: "bg-sky-950 text-sky-300 border-sky-800",
  processing: "bg-amber-950 text-amber-300 border-amber-800",
  completed: "bg-emerald-950 text-emerald-300 border-emerald-800",
  blocked: "bg-red-950 text-red-300 border-red-800",
};

function Signal({ label, value }: { label: string; value?: string | boolean | null }) {
  const shown = value === true ? "true" : value === false ? "false" : value || "未標示";
  return (
    <span className="rounded border border-zinc-800 bg-zinc-950 px-2 py-1 text-[10px] text-zinc-400">
      {label}: <b className="font-mono font-normal text-zinc-200">{shown}</b>
    </span>
  );
}

export default function TaskBoard() {
  const [tasks, setTasks] = useState<Task[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [detail, setDetail] = useState<TaskDetail | null>(null);
  const [openFile, setOpenFile] = useState<string | null>(null);

  useEffect(() => {
    fetchTasks().then((data) => setTasks(Array.isArray(data) ? data : [])).catch(() => {});
  }, []);

  useEffect(() => {
    if (!selected) {
      const resetTimer = window.setTimeout(() => setDetail(null), 0);
      return () => window.clearTimeout(resetTimer);
    }
    fetchTask(selected).then(setDetail).catch(() => setDetail(null));
  }, [selected]);

  const summary = useMemo(() => ({
    blocked: tasks.filter((task) => task.normalized_status === "blocked").length,
    approvals: tasks.filter((task) => task.pending_approval).length,
    reviews: tasks.filter((task) => task.review_status).length,
  }), [tasks]);

  return (
    <div className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900">
      <div className="flex items-center gap-2 border-b border-zinc-800 px-5 py-3">
        <ClipboardList size={16} className="text-blue-400" />
        <h2 className="text-sm font-semibold uppercase tracking-wide text-zinc-200">工單監控</h2>
        <span className="ml-auto text-xs text-zinc-500">
          {tasks.length} 張 · {summary.blocked} 受阻 · {summary.approvals} 待核准 · {summary.reviews} verify
        </span>
      </div>

      <div className="max-h-96 divide-y divide-zinc-800 overflow-y-auto">
        {tasks.map((task) => (
          <div key={task.id}>
            <button
              onClick={() => {
                setSelected(task.id === selected ? null : task.id);
                setOpenFile(null);
              }}
              className="flex w-full items-start gap-3 px-4 py-3 text-left transition hover:bg-zinc-800"
            >
              <span className="mt-0.5 text-zinc-600">
                {selected === task.id ? <ChevronDown size={13} /> : <ChevronRight size={13} />}
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2">
                  <p className="truncate text-xs font-medium text-zinc-200">{task.title}</p>
                  {task.pending_approval && <LockKeyhole size={12} className="shrink-0 text-amber-300" />}
                  {task.failure_reason && <AlertTriangle size={12} className="shrink-0 text-red-300" />}
                  {task.review_status && <ShieldQuestion size={12} className="shrink-0 text-purple-300" />}
                </div>
                <p className="mt-0.5 truncate font-mono text-[10px] text-zinc-600">
                  {task.mtime_str} · {task.dispatch_id}
                </p>
                <p className="mt-1 line-clamp-2 text-[11px] leading-relaxed text-zinc-400">
                  <span className="font-semibold text-zinc-300">目的：</span>{task.purpose}
                </p>
                <div className="mt-2 flex flex-wrap gap-1.5">
                  <Signal label="route" value={task.route_to} />
                  <Signal label="type" value={task.task_type} />
                  <Signal label="verify" value={task.review_status || (task.has_claude_review ? "legacy_review" : "")} />
                  <Signal label="models" value={task.models_invoked} />
                  <Signal label="external" value={task.external_actions_invoked} />
                </div>
              </div>
              <span className={`shrink-0 rounded border px-2 py-0.5 text-[10px] font-semibold ${statusColor[task.normalized_status]}`}>
                {statusLabel[task.normalized_status]}
              </span>
            </button>

            {selected === task.id && (
              <div className="space-y-3 bg-zinc-950 px-4 pb-3">
                <div className="rounded-lg border border-blue-900/70 bg-blue-950/30 p-3">
                  <p className="mb-1 text-[10px] font-semibold uppercase tracking-wide text-blue-300">
                    這張工單要做什麼
                  </p>
                  <p className="text-xs leading-relaxed text-zinc-200">{task.purpose}</p>
                  {(task.parent_dispatch_id || task.source_dispatch_id) && (
                    <p className="mt-2 break-all font-mono text-[9px] text-zinc-500">
                      上層工單：{task.parent_dispatch_id || task.source_dispatch_id}
                    </p>
                  )}
                </div>

                <div className="grid grid-cols-2 gap-2 text-[10px]">
                  <Signal label="dispatch_status" value={task.dispatch_status} />
                  <Signal label="task_status" value={task.task_status} />
                  <Signal label="approval" value={task.approval} />
                  <Signal label="cleanup" value={task.cleanup_executed} />
                  <Signal label="governance" value={task.governance_version} />
                  <Signal label="workflow" value={task.workflow_version} />
                  <Signal label="risk" value={task.risk_hits} />
                  <Signal label="escalation" value={task.escalation_status} />
                  <Signal label="review_flow" value={task.has_review_flow_status} />
                </div>

                {task.failure_reason && (
                  <p className="rounded border border-red-900 bg-red-950/40 px-3 py-2 text-[11px] text-red-200">
                    {task.failure_reason}
                  </p>
                )}

                <div className="space-y-1 rounded border border-zinc-800 bg-black/30 p-3 text-[10px] text-zinc-400">
                  <p className="flex items-center gap-1"><FileText size={11} /> artifact: <span className="break-all font-mono text-zinc-300">{task.artifact_path}</span></p>
                  {task.result_path && <p className="break-all font-mono">result: {task.result_path}</p>}
                  <p className="flex items-center gap-1"><CheckCircle2 size={11} /> evidence: {task.evidence_files.join(", ") || "none"}</p>
                </div>

                {detail && Object.entries(detail.files).map(([fname, content]) => (
                  <div key={fname} className="overflow-hidden rounded-lg border border-zinc-800">
                    <button
                      onClick={() => setOpenFile(openFile === fname ? null : fname)}
                      className="flex w-full items-center gap-2 px-3 py-1.5 text-[11px] transition hover:bg-zinc-800"
                    >
                      {openFile === fname ? <ChevronDown size={11} /> : <ChevronRight size={11} />}
                      <span className="font-mono text-zinc-400">{fname}</span>
                    </button>
                    {openFile === fname && (
                      <pre className="max-h-72 overflow-y-auto overflow-x-auto whitespace-pre-wrap bg-black p-3 text-[11px] leading-relaxed text-zinc-300">
                        {content || "(empty)"}
                      </pre>
                    )}
                  </div>
                ))}
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}
