"use client";

import { useCallback, useEffect, useState } from "react";
import { AlertTriangle, RefreshCw } from "lucide-react";
import { fetchFailures } from "@/lib/api";

interface Failure { event_id: string; ts: string; runtime_id: string; dispatch_id?: string; action: string; error_class?: string; exit_code?: number; output_ref?: string; next_step?: string }

export default function FailurePath() {
  const [items, setItems] = useState<Failure[]>([]);
  const refresh = useCallback(async () => { const data = await fetchFailures(); setItems(data.failures ?? []); }, []);
  useEffect(() => { const initial = window.setTimeout(() => void refresh(), 0); return () => window.clearTimeout(initial); }, [refresh]);
  return (
    <section className="h-full overflow-y-auto">
      <div className="mb-3 flex items-center gap-2"><AlertTriangle size={14} className="text-red-400" /><h2 className="text-xs font-semibold">Failure path</h2><button onClick={() => void refresh()} title="Refresh failures" className="ml-auto text-zinc-500"><RefreshCw size={12} /></button></div>
      <div className="space-y-2">{items.map((item) => <article key={item.event_id} className="border border-red-950 bg-zinc-900 p-3 text-[10px]"><div className="flex gap-2"><strong className="text-red-300">{item.error_class ?? "UNKNOWN"}</strong><span className="font-mono text-zinc-500">{item.ts}</span><span className="ml-auto">exit {item.exit_code ?? "unknown"}</span></div><p className="mt-1 font-mono text-zinc-400">{item.runtime_id} / {item.dispatch_id ?? "no dispatch"} / {item.action}</p><p className="mt-1 break-all font-mono text-zinc-600">artifact: {item.output_ref ?? "none"}</p><p className="break-all font-mono text-zinc-600">next: {item.next_step ?? "none"}</p></article>)}</div>
      {!items.length && <p className="text-xs text-zinc-500">No structured failures recorded.</p>}
    </section>
  );
}
