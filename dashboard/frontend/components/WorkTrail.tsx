"use client";

import { useEffect, useState, useRef } from "react";
import { fetchBridgeSessions, fetchBridgeSession, wsUrl } from "@/lib/api";
import { GitBranch, ChevronRight, ChevronDown, RefreshCw } from "lucide-react";

interface BridgeSession {
  id: string;
  files: string[];
  mtime: number;
  mtime_str: string;
}

interface SessionDetail {
  id: string;
  files: Record<string, string>;
}

type DayFilter = "today" | "yesterday" | "week" | "all";

const FILE_ORDER = [
  "01_HERMES_DISPATCH.md",
  "02_CODEX_OUTPUT.md",
  "03_CLAUDE_REVIEW.md",
  "04_HERMES_FINAL_SUMMARY.zh-TW.md",
  "04_HERMES_FINAL_SUMMARY.ascii.md",
  "TRANSCRIPT.md",
];

const FILE_LABELS: Record<string, { label: string; dot: string }> = {
  "01_HERMES_DISPATCH.md":            { label: "Hermes → Dispatch",      dot: "bg-purple-400" },
  "02_CODEX_OUTPUT.md":               { label: "Codex → Output",         dot: "bg-blue-400" },
  "03_CLAUDE_REVIEW.md":              { label: "Claude → Review",        dot: "bg-emerald-400" },
  "04_HERMES_FINAL_SUMMARY.zh-TW.md": { label: "Hermes → Summary (ZH)", dot: "bg-purple-300" },
  "04_HERMES_FINAL_SUMMARY.ascii.md": { label: "Hermes → Summary",      dot: "bg-purple-300" },
  "TRANSCRIPT.md":                    { label: "Full Transcript",        dot: "bg-zinc-500" },
};

function dayStart(offset: number): number {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - offset);
  return d.getTime() / 1000;
}

function filterSessions(sessions: BridgeSession[], filter: DayFilter): BridgeSession[] {
  if (filter === "all") return sessions;
  const from =
    filter === "today" ? dayStart(0) :
    filter === "yesterday" ? dayStart(1) :
    dayStart(7);
  const to =
    filter === "yesterday" ? dayStart(0) : Infinity;
  return sessions.filter(s => s.mtime >= from && s.mtime < to);
}

function sessionTypeColor(id: string): string {
  if (id.startsWith("tripartite")) return "bg-purple-900/60 text-purple-300";
  if (id.startsWith("claude")) return "bg-emerald-900/60 text-emerald-300";
  return "bg-zinc-800 text-zinc-300";
}

const FILTER_LABELS: { key: DayFilter; label: string }[] = [
  { key: "today", label: "今天" },
  { key: "yesterday", label: "昨天" },
  { key: "week", label: "本週" },
  { key: "all", label: "全部" },
];

export default function WorkTrail() {
  const [sessions, setSessions] = useState<BridgeSession[]>([]);
  const [filter, setFilter] = useState<DayFilter>("today");
  const [selected, setSelected] = useState<string | null>(null);
  const [detail, setDetail] = useState<SessionDetail | null>(null);
  const [openFile, setOpenFile] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const wsRef = useRef<WebSocket | null>(null);

  const load = () => {
    setLoading(true);
    fetchBridgeSessions()
      .then(setSessions)
      .catch(() => {})
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    const initial = window.setTimeout(() => void load(), 0);
    const ws = new WebSocket(wsUrl("/ws/bridge/latest"));
    wsRef.current = ws;
    ws.onmessage = (e) => {
      const msg = JSON.parse(e.data);
      if (msg.type === "new_session") {
        setSessions((prev) => {
          const s = msg.session;
          const entry: BridgeSession = {
            id: s.id,
            files: Object.keys(s.files),
            mtime: Date.now() / 1000,
            mtime_str: new Date().toLocaleString("zh-TW", { hour12: false }),
          };
          return [entry, ...prev];
        });
      }
    };
    return () => {
      window.clearTimeout(initial);
      ws.close();
    };
  }, []);

  useEffect(() => {
    if (!selected) {
      const resetTimer = window.setTimeout(() => setDetail(null), 0);
      return () => window.clearTimeout(resetTimer);
    }
    fetchBridgeSession(selected).then(setDetail).catch(() => {});
  }, [selected]);

  const visible = filterSessions(sessions, filter);

  const sortedFiles = detail
    ? [
        ...FILE_ORDER.filter((f) => f in detail.files),
        ...Object.keys(detail.files).filter((f) => !FILE_ORDER.includes(f)),
      ]
    : [];

  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-xl flex flex-col overflow-hidden">
      {/* Header + filter */}
      <div className="flex items-center gap-2 px-4 py-3 border-b border-zinc-800 flex-shrink-0">
        <GitBranch size={15} className="text-purple-400" />
        <h2 className="text-sm font-semibold text-zinc-200 tracking-wide uppercase">工作軌跡</h2>
        <span className="text-xs text-zinc-600">Hermes → Codex → Claude</span>

        {/* Day filter tabs */}
        <div className="flex gap-1 ml-auto">
          {FILTER_LABELS.map(({ key, label }) => (
            <button
              key={key}
              onClick={() => setFilter(key)}
              className={`text-[11px] px-2.5 py-1 rounded-md font-medium transition ${
                filter === key
                  ? "bg-zinc-700 text-zinc-100"
                  : "text-zinc-500 hover:text-zinc-300"
              }`}
            >
              {label}
              {key !== "all" && (
                <span className="ml-1 text-[10px] text-zinc-600">
                  ({filterSessions(sessions, key).length})
                </span>
              )}
            </button>
          ))}
          <button onClick={load} className="ml-1 text-zinc-600 hover:text-zinc-400 transition">
            <RefreshCw size={12} className={loading ? "animate-spin" : ""} />
          </button>
        </div>
      </div>

      <div className="flex overflow-hidden" style={{ maxHeight: 380 }}>
        {/* Session list */}
        <div className="w-52 border-r border-zinc-800 overflow-y-auto flex-shrink-0">
          {visible.length === 0 && !loading && (
            <p className="text-xs text-zinc-600 p-4 text-center">
              {filter === "today" ? "今天沒有 session" : "無資料"}
            </p>
          )}
          {visible.map((s) => (
            <button
              key={s.id}
              onClick={() => { setSelected(s.id === selected ? null : s.id); setOpenFile(null); }}
              className={`w-full text-left px-3 py-2 border-b border-zinc-800/60 hover:bg-zinc-800 transition ${selected === s.id ? "bg-zinc-800" : ""}`}
            >
              <div className="flex items-center gap-1.5 mb-0.5">
                <span className={`text-[9px] px-1.5 py-0.5 rounded font-semibold ${sessionTypeColor(s.id)}`}>
                  {s.id.startsWith("tripartite") ? "3-WAY" : "CLAUDE"}
                </span>
              </div>
              <p className="text-[11px] text-zinc-300 font-mono leading-tight truncate">
                {s.id.replace(/^(tripartite|claude)_/, "")}
              </p>
              <p className="text-[10px] text-zinc-600 mt-0.5">{s.mtime_str}</p>
            </button>
          ))}
        </div>

        {/* Detail */}
        <div className="flex-1 overflow-y-auto">
          {!selected && (
            <div className="flex items-center justify-center h-full text-zinc-700 text-xs">
              ← 選擇 session
            </div>
          )}
          {selected && detail && (
            <div className="p-3 space-y-1.5">
              {sortedFiles.map((fname) => {
                const meta = FILE_LABELS[fname] ?? { label: fname, dot: "bg-zinc-600" };
                const isOpen = openFile === fname;
                const content = detail.files[fname] ?? "";
                return (
                  <div key={fname} className="border border-zinc-800 rounded-lg overflow-hidden">
                    <button
                      onClick={() => setOpenFile(isOpen ? null : fname)}
                      className="w-full flex items-center gap-2 px-3 py-2 text-xs hover:bg-zinc-800 transition"
                    >
                      <span className={`w-2 h-2 rounded-full flex-shrink-0 ${meta.dot}`} />
                      {isOpen ? <ChevronDown size={11} /> : <ChevronRight size={11} />}
                      <span className="text-zinc-300 font-medium">{meta.label}</span>
                      <span className="text-zinc-600 ml-auto text-[10px]">
                        {content ? `${content.split("\n").length} lines` : "empty"}
                      </span>
                    </button>
                    {isOpen && (
                      <pre className="text-[11px] text-zinc-300 bg-zinc-950 p-3 overflow-x-auto whitespace-pre-wrap leading-relaxed max-h-64 overflow-y-auto">
                        {content || "(empty)"}
                      </pre>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
