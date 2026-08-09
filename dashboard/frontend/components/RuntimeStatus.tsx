"use client";

import { useCallback, useEffect, useState } from "react";
import { Activity, AlertTriangle, ChevronDown, RefreshCw } from "lucide-react";
import { fetchRuntimeHistory, fetchRuntimes } from "@/lib/api";

interface RuntimeItem {
  runtime_id: string; display_name: string; kind: string; enabled: boolean;
  expected_identity?: string; depends_on?: string[];
  status: { state: string; pids?: number[]; observed_identity?: string | null; evidence_summary?: string; heartbeat?: { observed_at: string } | null };
}
interface Snapshot { collected_at: string; runtimes: Array<{ runtime_id: string; state: string; scheduled_run?: { last_run: string; last_result: number | null; task_state: string } | null }> }

const dot: Record<string, string> = {
  healthy: "bg-emerald-400", running: "bg-emerald-400", degraded: "bg-amber-400",
  down: "bg-red-400", unknown: "bg-amber-400", idle: "bg-zinc-500", disabled: "bg-zinc-700",
};
const groups = [
  { key: "core", label: "Core services", match: (item: RuntimeItem) => item.enabled && ["daemon", "api", "embedded"].includes(item.kind) },
  { key: "work", label: "Event workers", match: (item: RuntimeItem) => item.enabled && item.kind === "per_event" },
  { key: "scheduled", label: "Scheduled jobs", match: (item: RuntimeItem) => item.enabled && item.kind === "scheduled" },
  { key: "optional", label: "Disabled / optional", match: (item: RuntimeItem) => !item.enabled },
];

export default function RuntimeStatus() {
  const [items, setItems] = useState<RuntimeItem[]>([]);
  const [history, setHistory] = useState<Snapshot[]>([]);
  const [expanded, setExpanded] = useState(false);
  const [selected, setSelected] = useState<string | null>(null);
  const [runIdx, setRunIdx] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [stale, setStale] = useState(false);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const [runtimeData, historyData] = await Promise.all([fetchRuntimes(), fetchRuntimeHistory()]);
      setItems(Array.isArray(runtimeData.runtimes) ? runtimeData.runtimes : []);
      setHistory(Array.isArray(historyData.snapshots) ? historyData.snapshots : []);
      setError(runtimeData.evidence_error ?? null);
      setStale(Boolean(runtimeData.evidence_stale));
    } catch (reason) { setError(reason instanceof Error ? reason.message : "backend unavailable"); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => {
    const initial = window.setTimeout(() => void refresh(), 0);
    const interval = window.setInterval(() => void refresh(), 15000);
    return () => { window.clearTimeout(initial); window.clearInterval(interval); };
  }, [refresh]);

  const core = items.filter(groups[0].match);
  const coreHealthy = core.filter((item) => ["healthy", "running"].includes(item.status.state)).length;
  const active = items.filter((item) => item.kind === "per_event" && item.status.state === "running").length;
  const attention = items.filter((item) => item.enabled && ["down", "degraded", "unknown"].includes(item.status.state)).length;
  const chosen = items.find((item) => item.runtime_id === selected) ?? null;
  const rawHistory = history.map((snapshot) => {
    const entry = snapshot.runtimes.find((item) => item.runtime_id === selected);
    return { at: entry?.scheduled_run?.last_run ?? snapshot.collected_at, state: entry?.scheduled_run ? (entry.scheduled_run.last_result === 0 ? "healthy" : "down") : (entry?.state ?? "unknown"), run: entry?.scheduled_run ?? null };
  });
  const chosenHistory = chosen?.kind === "scheduled"
    ? rawHistory.filter((entry, index, all) => Boolean(entry.run) && all.findIndex((candidate) => candidate.at === entry.at) === index)
    : rawHistory;

  return <section className="border-b border-zinc-800 bg-zinc-950 px-4 py-3">
    <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
      <div className="border-t-2 border-emerald-700 pt-2"><p className="text-[10px] text-zinc-500">Core services</p><p className="text-xl font-semibold">{coreHealthy}/{core.length}</p><p className="text-[10px] text-zinc-500">healthy</p></div>
      <div className="border-t-2 border-cyan-700 pt-2"><p className="text-[10px] text-zinc-500">Active work</p><p className="text-xl font-semibold">{active}</p><p className="text-[10px] text-zinc-500">workers running</p></div>
      <div className="border-t-2 border-zinc-700 pt-2"><p className="text-[10px] text-zinc-500">Registered</p><p className="text-xl font-semibold">{items.length}</p><p className="text-[10px] text-zinc-500">all runtime types</p></div>
      <div className={`border-t-2 pt-2 ${attention ? "border-red-700" : "border-emerald-700"}`}><p className="text-[10px] text-zinc-500">Needs attention</p><p className="text-xl font-semibold">{attention}</p><p className="text-[10px] text-zinc-500">enabled runtimes</p></div>
    </div>
    <div className="mt-3 flex items-center gap-2 border-t border-zinc-800 pt-3">
      <Activity size={14} className="text-emerald-400"/><h2 className="text-xs font-semibold">Runtime</h2>
      <span className="text-[10px] text-zinc-500">{stale ? "stale evidence" : "live snapshot"}</span>
      <button className="ml-auto text-zinc-500" onClick={() => void refresh()} title="Refresh runtime evidence"><RefreshCw size={13} className={loading ? "animate-spin" : ""}/></button>
      <button className="text-zinc-500" onClick={() => setExpanded((value) => !value)} title="Toggle runtime details" aria-expanded={expanded}><ChevronDown size={14} className={expanded ? "rotate-180" : ""}/></button>
    </div>
    {(error || stale) && <div className="mt-2 flex items-center gap-2 border border-amber-800 bg-amber-950 px-3 py-2 text-[11px] text-amber-200"><AlertTriangle size={13}/>{error ?? "Runtime evidence is stale"}</div>}
    {expanded && <div className="mt-3 grid gap-4 xl:grid-cols-[minmax(0,2fr)_minmax(280px,1fr)]">
      <div className="space-y-4">{groups.map((group) => { const members = items.filter(group.match); return <div key={group.key}>
        <div className="mb-1 flex items-center justify-between"><h3 className="text-[11px] font-semibold text-zinc-300">{group.label}</h3><span className="text-[9px] text-zinc-600">{members.length}</span></div>
        <div className="divide-y divide-zinc-800 border-y border-zinc-800">{members.map((item) => <button key={item.runtime_id} onClick={() => { setSelected(item.runtime_id); setRunIdx(null); }} className={`grid w-full grid-cols-[12px_minmax(0,1fr)_80px] items-center gap-2 px-2 py-2 text-left text-[10px] hover:bg-zinc-900 ${selected === item.runtime_id ? "bg-zinc-900" : ""}`}>
          <i className={`h-2 w-2 rounded-full ${dot[item.status.state] ?? dot.unknown}`}/><span className="truncate">{item.display_name}</span><span className="text-right text-zinc-500">{item.status.state}</span>
        </button>)}</div></div> })}</div>
      <aside className="border-l border-zinc-800 pl-4">{chosen ? <>
        <h3 className="text-xs font-semibold">{chosen.display_name}</h3><p className="mt-1 font-mono text-[9px] text-zinc-500">{chosen.runtime_id}</p>
        <div className="mt-4 flex min-h-10 items-end gap-1" aria-label="Recent runtime state history">{chosenHistory.map((entry, index) => <button type="button" key={`${entry.at}-${index}`} onClick={() => setRunIdx(runIdx === index ? null : index)} title={`${entry.at}: ${entry.run ? `exit ${entry.run.last_result}` : entry.state}`} className={`h-6 min-w-1 flex-1 cursor-pointer ${dot[entry.state] ?? dot.unknown} ${runIdx === index ? "ring-2 ring-cyan-400" : ""}`}/>)}</div>
        <p className="mt-2 text-[9px] text-zinc-600">{chosenHistory.length ? `${chosenHistory.length} ${chosen.kind === "scheduled" ? "recorded runs" : "recent snapshots"} — 點 bar 看單次詳情` : chosen.kind === "scheduled" ? "No recorded runs in this window" : "History begins after this deployment"}</p>
        {runIdx !== null && chosenHistory[runIdx] && <div className="mt-2 border border-zinc-800 bg-zinc-900 p-2 font-mono text-[9px] text-zinc-400">
          <p className="text-zinc-300">run snapshot</p>
          <p>time: {chosenHistory[runIdx].at}</p>
          <p>state: {chosenHistory[runIdx].state}</p>
          {chosenHistory[runIdx].run
            ? <><p>exit_code: {String(chosenHistory[runIdx].run!.last_result ?? "unknown")}</p><p>task_state: {chosenHistory[runIdx].run!.task_state || "unknown"}</p><p>last_run: {chosenHistory[runIdx].run!.last_run}</p></>
            : <p>collector snapshot only（此 runtime 該時點無 scheduled run 紀錄）</p>}
        </div>}
        <div className="mt-4 space-y-1 break-words font-mono text-[9px] text-zinc-500"><p>state: {chosen.status.state}</p><p>pid: {chosen.status.pids?.join(", ") || "none"}</p><p>identity: {chosen.status.observed_identity ?? "unknown"}</p><p>depends: {chosen.depends_on?.join(", ") || "none"}</p><p>evidence: {chosen.status.evidence_summary ?? "not collected"}</p></div>
      </> : <p className="text-[10px] text-zinc-600">Select a runtime to inspect history and evidence.</p>}</aside>
    </div>}
  </section>;
}
