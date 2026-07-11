"use client";

import { FormEvent, useState } from "react";
import { GitBranch, Search } from "lucide-react";
import { fetchRuntimeEvents } from "@/lib/api";

interface EventRow {
  event_id: string; ts: string; actor: string; runtime_id: string; action: string;
  result: string; script?: string; input_ref?: string; output_ref?: string; next_step?: string;
}

export default function DecisionMap() {
  const [dispatchId, setDispatchId] = useState("");
  const [events, setEvents] = useState<EventRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  async function search(event: FormEvent) {
    event.preventDefault(); setError(null);
    try {
      const data = await fetchRuntimeEvents(undefined, dispatchId.trim());
      setEvents((data.events ?? []).slice().reverse());
    } catch (reason) { setError(reason instanceof Error ? reason.message : "query failed"); }
  }
  return (
    <section className="h-full overflow-y-auto bg-zinc-950 p-5">
      <div className="mb-4 flex items-center gap-2"><GitBranch size={15} className="text-cyan-400" /><h2 className="text-sm font-semibold">Decision path</h2></div>
      <form onSubmit={search} className="mb-5 flex max-w-3xl gap-2">
        <input value={dispatchId} onChange={(event) => setDispatchId(event.target.value)} placeholder="Exact dispatch ID" className="min-w-0 flex-1 border border-zinc-700 bg-zinc-900 px-3 py-2 font-mono text-xs outline-none focus:border-cyan-600" />
        <button disabled={!dispatchId.trim()} title="Load decision path" className="h-8 w-8 border border-cyan-700 bg-cyan-900"><Search size={13} className="mx-auto" /></button>
      </form>
      {error && <p className="mb-3 border border-red-900 bg-red-950 p-3 text-xs text-red-200">{error}</p>}
      <div className="max-w-5xl space-y-0">
        {events.map((item, index) => (
          <div key={item.event_id} className="grid grid-cols-[24px_minmax(0,1fr)] gap-3">
            <div className="flex flex-col items-center"><span className={`mt-4 h-2.5 w-2.5 rounded-full ${item.result === "error" ? "bg-red-500" : "bg-emerald-500"}`} />{index < events.length - 1 && <span className="w-px flex-1 bg-zinc-700" />}</div>
            <article className="mb-3 border border-zinc-800 bg-zinc-900 p-3 text-[10px]">
              <div className="flex gap-3"><strong className="text-zinc-200">{item.actor} · {item.action}</strong><span className="font-mono text-zinc-500">{item.ts}</span><span className="ml-auto text-zinc-400">{item.result}</span></div>
              <div className="mt-2 grid gap-1 font-mono text-zinc-500 md:grid-cols-2"><p className="truncate">script: {item.script ?? "unknown"}</p><p className="truncate">runtime: {item.runtime_id}</p><p className="truncate">input: {item.input_ref ?? "none"}</p><p className="truncate">output: {item.output_ref ?? "none"}</p><p className="truncate md:col-span-2">next: {item.next_step ?? "none"}</p></div>
            </article>
          </div>
        ))}
        {!events.length && <p className="text-xs text-zinc-500">Enter an exact dispatch ID to reconstruct its recorded path.</p>}
      </div>
    </section>
  );
}
