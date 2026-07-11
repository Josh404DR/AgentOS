"use client";

import { useCallback, useEffect, useState } from "react";
import { RefreshCw, Workflow } from "lucide-react";
import { fetchRuntimeEvents } from "@/lib/api";

interface RuntimeEvent {
  event_id: string; ts: string; actor: string; runtime_id: string; dispatch_id?: string;
  action: string; result: string; exit_code?: number | null; input_ref?: string | null;
  output_ref?: string | null; next_step?: string | null;
}

export default function EventTimeline() {
  const [events, setEvents] = useState<RuntimeEvent[]>([]);
  const [loading, setLoading] = useState(false);
  const refresh = useCallback(async () => {
    setLoading(true);
    try { const data = await fetchRuntimeEvents(); setEvents(Array.isArray(data.events) ? data.events : []); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => {
    const initial = window.setTimeout(() => void refresh(), 0);
    const interval = window.setInterval(() => void refresh(), 10000);
    return () => { window.clearTimeout(initial); window.clearInterval(interval); };
  }, [refresh]);

  return (
    <section className="h-full overflow-y-auto bg-zinc-950 p-5">
      <div className="mb-4 flex items-center gap-2">
        <Workflow size={15} className="text-cyan-400" /><h2 className="text-sm font-semibold">Dispatch event timeline</h2>
        <button onClick={() => void refresh()} className="ml-auto text-zinc-500" title="Refresh events"><RefreshCw size={13} className={loading ? "animate-spin" : ""} /></button>
      </div>
      <div className="space-y-2">
        {events.map((event) => (
          <article key={event.event_id} className="grid grid-cols-[160px_120px_1fr] gap-3 border border-zinc-800 bg-zinc-900 p-3 text-[10px]">
            <div className="font-mono text-zinc-500">{event.ts}<br />{event.actor}</div>
            <div><p className="text-zinc-200">{event.runtime_id}</p><p className={event.result === "error" ? "text-red-300" : "text-emerald-300"}>{event.action} · {event.result}</p></div>
            <div className="min-w-0 space-y-1 font-mono text-zinc-500"><p className="truncate">dispatch: {event.dispatch_id ?? "none"}</p><p className="truncate">input: {event.input_ref ?? "none"}</p><p className="truncate">output: {event.output_ref ?? "none"}</p><p className="truncate">next: {event.next_step ?? "none"} · exit: {event.exit_code ?? "unknown"}</p></div>
          </article>
        ))}
        {!events.length && <p className="text-xs text-zinc-500">No structured runtime events have been recorded yet.</p>}
      </div>
    </section>
  );
}
