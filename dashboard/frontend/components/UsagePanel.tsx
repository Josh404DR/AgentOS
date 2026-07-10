"use client";

import { useCallback, useEffect, useState } from "react";
import { AlertTriangle, Calendar, Clock, Cpu, Database, Gauge } from "lucide-react";
import { fetchUsage } from "@/lib/api";

interface UsageWindow {
  session_count: number;
  input_tokens: number;
  output_tokens: number;
  est_cost: number;
}

interface UsageData {
  total?: UsageWindow;
  window_5h?: UsageWindow;
  window_7d?: UsageWindow;
  current_model?: string;
  error?: string;
}

function fmt(value: number | null | undefined): string {
  if (value == null || Number.isNaN(value)) return "unknown";
  if (value >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`;
  if (value >= 1_000) return `${(value / 1_000).toFixed(0)}K`;
  return String(value);
}

function tokens(window: UsageWindow | undefined): number {
  return (window?.input_tokens ?? 0) + (window?.output_tokens ?? 0);
}

export default function UsagePanel() {
  const [data, setData] = useState<UsageData>({});
  const [lastSuccess, setLastSuccess] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const incoming = await fetchUsage();
      setData(incoming);
      setError(incoming.error ?? null);
      setLastSuccess(new Date().toLocaleTimeString("zh-TW", { hour12: false }));
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "usage source unavailable");
    }
  }, []);

  useEffect(() => {
    const initial = window.setTimeout(() => void load(), 0);
    const interval = window.setInterval(() => void load(), 30000);
    return () => {
      window.clearTimeout(initial);
      window.clearInterval(interval);
    };
  }, [load]);

  return (
    <section className="space-y-3 border border-zinc-800 bg-zinc-900 p-4">
      <div className="flex items-center gap-2">
        <Gauge size={14} className="text-cyan-400" />
        <h2 className="text-xs font-semibold text-zinc-200">Usage evidence</h2>
        <span className="ml-auto text-[9px] text-zinc-600">last success: {lastSuccess ?? "none"}</span>
      </div>

      {error && <p className="flex items-center gap-1 border border-red-900 bg-red-950 px-2 py-1 text-[10px] text-red-200"><AlertTriangle size={11} />{error}</p>}

      <div className="grid grid-cols-2 gap-2">
        <div className="border border-zinc-800 bg-zinc-950 p-2">
          <p className="flex items-center gap-1 text-[10px] text-zinc-500"><Clock size={10} />Recorded, 5 hours</p>
          <p className="mt-1 font-mono text-sm text-zinc-100">{fmt(tokens(data.window_5h))} tokens</p>
          <p className="text-[9px] text-zinc-600">{data.window_5h?.session_count ?? 0} sessions</p>
        </div>
        <div className="border border-zinc-800 bg-zinc-950 p-2">
          <p className="flex items-center gap-1 text-[10px] text-zinc-500"><Calendar size={10} />Recorded, 7 days</p>
          <p className="mt-1 font-mono text-sm text-zinc-100">{fmt(tokens(data.window_7d))} tokens</p>
          <p className="text-[9px] text-zinc-600">{data.window_7d?.session_count ?? 0} sessions</p>
        </div>
      </div>

      <div className="space-y-1 border-t border-zinc-800 pt-2 text-[10px]">
        <p className="flex items-center gap-2 text-zinc-400"><Database size={10} />Source: Hermes local session database</p>
        <p className="flex items-center gap-2 text-zinc-400"><Cpu size={10} />Current recorded model: <span className="font-mono text-zinc-200">{data.current_model ?? "unknown"}</span></p>
        <p className="flex items-center gap-2 text-amber-300"><Gauge size={10} />Provider quota: unknown (no authoritative quota API)</p>
      </div>
    </section>
  );
}
