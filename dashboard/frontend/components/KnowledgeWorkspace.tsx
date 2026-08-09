"use client";

import { FormEvent, useEffect, useState } from "react";
import { addKnowledgeFeedback, createKnowledgeDiscussion, fetchKnowledgeArtifact, fetchKnowledgeNode, searchKnowledge } from "@/lib/api";

type NodeItem = {
  dispatch_id: string;
  title: string;
  summary: string;
  source_url: string;
  agentos_value: string;
  similarity_score: string | number;
  relationship_status: string;
  local_sync_status: string;
  notebooklm_sync_status: string;
  artifact_refs: { kind: string; ref: string }[];
  discussion_events?: { event_id: string; type: string; content: string; actor_id: string; timestamp: string; discussion_id: string }[];
  stale?: boolean;
  projection_as_of?: string;
};

export default function KnowledgeWorkspace({ initialNode = "" }: { initialNode?: string }) {
  const [query, setQuery] = useState("");
  const [items, setItems] = useState<NodeItem[]>([]);
  const [selected, setSelected] = useState<NodeItem | null>(null);
  const [note, setNote] = useState("");
  const [error, setError] = useState("");
  const [projection, setProjection] = useState("");
  const [artifact, setArtifact] = useState<{ kind: string; content: string; sha256: string } | null>(null);

  async function runSearch(value = query) {
    try {
      const data = await searchKnowledge(value);
      setItems(data.items ?? []);
      setProjection(data.projection_as_of ?? "");
      setError("");
    } catch (e) { setError(String(e)); }
  }

  async function openNode(id: string) {
    try {
      const node = await fetchKnowledgeNode(id);
      setSelected(node);
      setArtifact(null);
      const url = new URL(window.location.href);
      url.searchParams.set("tab", "knowledge");
      url.searchParams.set("node", id);
      window.history.replaceState({}, "", url);
      setError("");
    } catch (e) { setError(String(e)); }
  }

  useEffect(() => { runSearch(""); }, []);
  useEffect(() => { if (initialNode) openNode(initialNode); }, [initialNode]);

  async function submitFeedback(event: FormEvent, discussion = false) {
    event.preventDefault();
    if (!selected || !note.trim()) return;
    try {
      if (discussion) await createKnowledgeDiscussion(selected.dispatch_id, note);
      else await addKnowledgeFeedback(selected.dispatch_id, note);
      setNote("");
      await openNode(selected.dispatch_id);
    } catch (e) { setError(`${String(e)}（請先以 owner token 登入）`); }
  }

  return (
    <div className="grid h-full min-h-[calc(100vh-60px)] grid-cols-1 lg:grid-cols-[360px_minmax(0,1fr)]">
      <aside className="border-r border-zinc-800 p-4">
        <h2 className="text-lg font-semibold">隔離知識附加區 / Isolated Knowledge Append Plane</h2>
        <p className="mb-3 text-xs text-zinc-500">衍生索引，可由 canonical artifacts 重建</p>
        <form onSubmit={(e) => { e.preventDefault(); runSearch(); }} className="flex gap-2">
          <input aria-label="搜尋知識" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="繁中關鍵字或工單編號" className="min-w-0 flex-1 border border-zinc-700 bg-zinc-900 px-3 py-2 text-sm" />
          <button className="bg-cyan-700 px-3 text-sm">搜尋</button>
        </form>
        <p className="my-2 text-[10px] text-zinc-600">projection_as_of: {projection || "loading"}</p>
        <div className="space-y-2 overflow-y-auto lg:max-h-[calc(100vh-180px)]">
          {items.map((item) => <button key={item.dispatch_id} onClick={() => openNode(item.dispatch_id)} className="w-full border border-zinc-800 p-3 text-left hover:border-cyan-700">
            <div className="text-xs font-semibold text-cyan-300">{item.title}</div>
            <div className="mt-1 line-clamp-3 text-xs text-zinc-400">{item.summary || item.dispatch_id}</div>
            <div className="mt-2 text-[10px] text-zinc-600">similarity_score: {String(item.similarity_score)}</div>
          </button>)}
        </div>
      </aside>
      <section className="overflow-y-auto p-5">
        {error && <div className="mb-3 border border-red-900 bg-red-950/40 p-3 text-xs text-red-300">{error}</div>}
        {!selected ? <div className="text-sm text-zinc-500">選擇一個知識節點查看來源、分析與討論。</div> : <div className="mx-auto max-w-4xl space-y-5">
          <div><h2 className="text-xl font-bold">{selected.title}</h2><p className="mt-1 break-all text-xs text-zinc-500">{selected.dispatch_id}</p></div>
          <div className="grid gap-2 text-xs sm:grid-cols-3"><span>local: {selected.local_sync_status}</span><span>NotebookLM: {selected.notebooklm_sync_status}</span><span>stale: {String(selected.stale)}</span></div>
          <article className="border border-zinc-800 p-4"><h3 className="mb-2 text-xs font-bold text-zinc-400">摘要</h3><p className="whitespace-pre-wrap text-sm">{selected.summary || "尚無摘要"}</p></article>
          <article className="border border-zinc-800 p-4"><h3 className="mb-2 text-xs font-bold text-zinc-400">AgentOS Value</h3><p className="whitespace-pre-wrap text-sm">{selected.agentos_value || "尚未評估"}</p></article>
          <div className="border border-zinc-800 p-4"><h3 className="mb-2 text-xs font-bold text-zinc-400">可稽核來源（opaque refs）</h3><div className="flex flex-wrap gap-2">{selected.artifact_refs.map((ref) => <button key={ref.ref} onClick={async () => setArtifact(await fetchKnowledgeArtifact(ref.ref))} className="border border-zinc-700 px-2 py-1 text-xs hover:border-cyan-700">{ref.kind}</button>)}</div>{artifact && <pre className="mt-3 max-h-80 overflow-auto whitespace-pre-wrap bg-black p-3 text-xs">[{artifact.kind}] sha256={artifact.sha256}{"\n\n"}{artifact.content}</pre>}</div>
          <div className="border border-zinc-800 p-4"><h3 className="mb-2 text-xs font-bold text-zinc-400">隔離知識附加區 / Isolated Knowledge Append Plane</h3><div className="space-y-2">{(selected.discussion_events ?? []).map((event) => <div key={event.event_id} className="bg-zinc-900 p-2 text-xs"><span className="text-cyan-400">{event.type}</span> · {event.actor_id}<p className="mt-1 whitespace-pre-wrap">{event.content}</p></div>)}</div><form className="mt-3 space-y-2"><textarea aria-label="Feedback 或討論" value={note} onChange={(e) => setNote(e.target.value)} className="h-24 w-full border border-zinc-700 bg-zinc-900 p-2 text-sm" placeholder="這些內容只寫入隔離 append-only storage，不修改知識節點。" /><div className="flex gap-2"><button onClick={(e) => submitFeedback(e, false)} className="bg-cyan-700 px-3 py-2 text-xs">加入 Feedback</button><button onClick={(e) => submitFeedback(e, true)} className="border border-zinc-700 px-3 py-2 text-xs">建立討論</button></div></form></div>
        </div>}
      </section>
    </div>
  );
}
