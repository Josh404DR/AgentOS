"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Activity, AlertTriangle, CircleStop, RefreshCw } from "lucide-react";
import { fetchRuntimes } from "@/lib/api";

interface RuntimeItem {
  runtime_id: string;
  display_name: string;
  kind: string;
  status: { state: string; pids?: number[]; observed_identity?: string };
}

const stateStyle: Record<string, string> = {
  healthy: "border-emerald-700 bg-emerald-950 text-emerald-200",
  running: "border-emerald-700 bg-emerald-950 text-emerald-200",
  idle: "border-zinc-700 bg-zinc-900 text-zinc-300",
  disabled: "border-zinc-800 bg-zinc-950 text-zinc-500",
  down: "border-red-800 bg-red-950 text-red-200",
  unknown: "border-amber-800 bg-amber-950 text-amber-200",
};

export default function RuntimeStatus() {
  const [items, setItems] = useState<RuntimeItem[]>([]);
  const [collectedAt, setCollectedAt] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const data = await fetchRuntimes();
      setItems(Array.isArray(data.runtimes) ? data.runtimes : []);
      setCollectedAt(data.collected_at ?? null);
      setError(data.evidence_error ?? null);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "backend unavailable");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const initial = window.setTimeout(() => void refresh(), 0);
    const interval = window.setInterval(() => void refresh(), 15000);
    return () => {
      window.clearTimeout(initial);
      window.clearInterval(interval);
    };
  }, [refresh]);

  const down = useMemo(() => items.filter((item) => item.status.state === "down").length, [items]);

  return (
    <section className="border-b border-zinc-800 bg-zinc-950 px-4 py-3">
      <div className="mb-2 flex items-center gap-2">
        <Activity size={15} className="text-emerald-400" />
        <h2 className="text-xs font-semibold text-zinc-200">Runtime health</h2>
        <span className="text-[10px] text-zinc-500">{items.length} registered, {down} down</span>
        <button className="ml-auto text-zinc-500 hover:text-zinc-200" onClick={() => void refresh()} title="Refresh runtime evidence">
          <RefreshCw size={13} className={loading ? "animate-spin" : ""} />
        </button>
      </div>
      {error && (
        <div className="mb-2 flex items-center gap-2 border border-amber-800 bg-amber-950 px-3 py-2 text-[11px] text-amber-200">
          <AlertTriangle size={13} /> Evidence degraded: {error}
        </div>
      )}
      <div className="grid grid-cols-2 gap-2 md:grid-cols-3 xl:grid-cols-5">
        {items.map((item) => (
          <div key={item.runtime_id} className={`min-w-0 border px-3 py-2 ${stateStyle[item.status.state] ?? stateStyle.unknown}`}>
            <div className="flex items-center gap-2">
              <CircleStop size={10} className="shrink-0" />
              <p className="truncate text-[11px] font-medium">{item.display_name}</p>
            </div>
            <p className="mt-1 truncate font-mono text-[9px] opacity-70">{item.status.state} · {item.kind}</p>
          </div>
        ))}
      </div>
      <p className="mt-2 text-right font-mono text-[9px] text-zinc-600">evidence: {collectedAt ?? "not collected"}</p>
    </section>
  );
}
