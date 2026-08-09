"use client";

import { FormEvent, MouseEvent as ReactMouseEvent, useCallback, useEffect, useRef, useState } from "react";
import { CheckCircle2, GitBranch, Link2, Map, Plus, RefreshCw, Search, X } from "lucide-react";
import { addDecisionLink, createDecision, fetchDecisions, fetchRuntimeEvents, saveDecisionLayout, setDecisionStatus } from "@/lib/api";

interface EventRow {
  event_id: string; ts: string; actor: string; runtime_id: string; action: string;
  result: string; script?: string; input_ref?: string; output_ref?: string; next_step?: string;
}
interface DecisionNode { id: string; title: string; status: string; date: string; body: string; position?: { x: number; y: number } | null }
interface DecisionEdge { source: string; target: string }

const NODE_W = 190; const NODE_H = 64;
const statusColor: Record<string, string> = {
  landed: "border-cyan-500 bg-cyan-950 text-cyan-100",
  accepted: "border-amber-600 bg-amber-950 text-amber-100",
  proposed: "border-emerald-500 bg-emerald-950 text-emerald-100",
  superseded: "border-zinc-700 bg-zinc-900 text-zinc-500",
};
const statusLabel: Record<string, string> = {
  landed: "已落地", accepted: "定案待實作", proposed: "新增待確認", superseded: "已被取代",
};

function StrategyMap() {
  const [nodes, setNodes] = useState<DecisionNode[]>([]);
  const [edges, setEdges] = useState<DecisionEdge[]>([]);
  const [pos, setPos] = useState<Record<string, { x: number; y: number }>>({});
  const [selected, setSelected] = useState<string | null>(null);
  const [linkTarget, setLinkTarget] = useState("");
  const [evidence, setEvidence] = useState("");
  const [formOpen, setFormOpen] = useState(false);
  const [title, setTitle] = useState(""); const [status, setStatus] = useState("proposed");
  const [bodyText, setBodyText] = useState(""); const [formLinks, setFormLinks] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const drag = useRef<{ id: string; dx: number; dy: number; moved: boolean } | null>(null);
  const canvasRef = useRef<HTMLDivElement | null>(null);

  const refresh = useCallback(async () => {
    try {
      const data = await fetchDecisions();
      const list: DecisionNode[] = Array.isArray(data.nodes) ? data.nodes : [];
      setNodes(list);
      setEdges(Array.isArray(data.edges) ? data.edges : []);
      setPos((previous) => {
        const next: Record<string, { x: number; y: number }> = {};
        list.forEach((node, index) => {
          next[node.id] = previous[node.id]
            ?? (node.position && Number.isFinite(node.position.x) ? { x: node.position.x, y: node.position.y } : null)
            ?? { x: 60 + (index % 4) * (NODE_W + 60), y: 60 + Math.floor(index / 4) * (NODE_H + 70) };
        });
        return next;
      });
      setError(null);
    } catch (reason) { setError(reason instanceof Error ? reason.message : "backend unavailable"); }
  }, []);
  useEffect(() => {
    const timer = window.setTimeout(() => void refresh(), 0);
    return () => window.clearTimeout(timer);
  }, [refresh]);

  const onNodeDown = (event: ReactMouseEvent, id: string) => {
    const rect = canvasRef.current?.getBoundingClientRect();
    if (!rect) return;
    const point = pos[id] ?? { x: 0, y: 0 };
    drag.current = { id, dx: event.clientX - rect.left - point.x + (canvasRef.current?.scrollLeft ?? 0), dy: event.clientY - rect.top - point.y + (canvasRef.current?.scrollTop ?? 0), moved: false };
  };
  const onMove = (event: ReactMouseEvent) => {
    const current = drag.current; const rect = canvasRef.current?.getBoundingClientRect();
    if (!current || !rect) return;
    current.moved = true;
    const x = Math.max(0, event.clientX - rect.left - current.dx + (canvasRef.current?.scrollLeft ?? 0));
    const y = Math.max(0, event.clientY - rect.top - current.dy + (canvasRef.current?.scrollTop ?? 0));
    setPos((previous) => ({ ...previous, [current.id]: { x, y } }));
  };
  const onUp = () => {
    const current = drag.current; drag.current = null;
    if (!current) return;
    if (!current.moved) { setSelected((value) => value === current.id ? null : current.id); setLinkTarget(""); setEvidence(""); return; }
    void saveDecisionLayout(pos).catch(() => undefined);
  };

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    try {
      await createDecision({ title, status, body: bodyText, links: formLinks });
      setFormOpen(false); setTitle(""); setBodyText(""); setFormLinks([]); setStatus("proposed");
      await refresh();
    } catch (reason) { setError(reason instanceof Error ? reason.message : "create failed"); }
  };
  const connect = async () => {
    if (!selected || !linkTarget) return;
    try { await addDecisionLink(selected, linkTarget); setLinkTarget(""); await refresh(); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "link failed"); }
  };
  const promote = async (status: string) => {
    if (!selected) return;
    if (status === "landed" && !evidence.trim() && !window.confirm("沒有附落地證據，確定標記落地？")) return;
    try { await setDecisionStatus(selected, status, evidence); setEvidence(""); await refresh(); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "status update failed"); }
  };

  const chosen = nodes.find((node) => node.id === selected) ?? null;
  const center = (id: string) => { const point = pos[id] ?? { x: 0, y: 0 }; return { x: point.x + NODE_W / 2, y: point.y + NODE_H / 2 }; };

  return <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_340px]">
    <div>
      <div className="mb-2 flex items-center gap-2">
        <button onClick={() => setFormOpen(true)} className="flex items-center gap-1.5 border border-cyan-700 bg-cyan-950 px-3 py-1.5 text-[11px] text-cyan-100"><Plus size={12}/>新增決策節點</button>
        <button onClick={() => void refresh()} title="Refresh" className="border border-zinc-700 p-1.5 text-zinc-400"><RefreshCw size={12}/></button>
        <span className="text-[10px] text-zinc-500">拖曳移動（自動存檔）· 點擊看全文 · 資料源 docs\decisions\ADR-*.md</span>
      </div>
      <div className="mb-2 flex flex-wrap items-center gap-3 text-[10px] text-zinc-400">
        <span className="flex items-center gap-1"><i className="h-2.5 w-2.5 border-2 border-cyan-500 bg-cyan-950"/>已落地 ✓</span>
        <span className="flex items-center gap-1"><i className="h-2.5 w-2.5 border-2 border-amber-600 bg-amber-950"/>定案待實作</span>
        <span className="flex items-center gap-1"><i className="h-2.5 w-2.5 border-2 border-emerald-500 bg-emerald-950"/>新增待確認</span>
        <span className="flex items-center gap-1"><i className="h-2.5 w-2.5 border-2 border-zinc-700 bg-zinc-900"/>已被取代</span>
      </div>
      {error && <p className="mb-2 border border-red-900 bg-red-950 p-2 text-[11px] text-red-200">{error}</p>}
      <div ref={canvasRef} onMouseMove={onMove} onMouseUp={onUp} onMouseLeave={onUp} className="relative h-[560px] overflow-auto border border-zinc-800 bg-zinc-950">
        <div className="relative" style={{ width: 1600, height: 1000 }}>
          <svg className="pointer-events-none absolute inset-0" width={1600} height={1000}>
            <defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto"><path d="M0,0 L7,3 L0,6 z" fill="#52525b"/></marker></defs>
            {edges.map((edge, index) => { const a = center(edge.source); const b = center(edge.target); return <line key={`${edge.source}-${edge.target}-${index}`} x1={a.x} y1={a.y} x2={b.x} y2={b.y} stroke="#52525b" strokeWidth={1.5} markerEnd="url(#arrow)"/>; })}
          </svg>
          {nodes.map((node) => { const point = pos[node.id] ?? { x: 0, y: 0 }; return (
            <div key={node.id} onMouseDown={(event) => onNodeDown(event, node.id)}
              className={`absolute cursor-grab select-none border-2 p-2 ${statusColor[node.status] ?? statusColor.proposed} ${selected === node.id ? "ring-2 ring-cyan-400" : ""}`}
              style={{ left: point.x, top: point.y, width: NODE_W, minHeight: NODE_H }}>
              <p className="flex items-start gap-1 text-[10px] font-semibold leading-tight">{node.status === "landed" && <CheckCircle2 size={11} className="mt-px shrink-0 text-cyan-300"/>}{node.title}</p>
              <p className="mt-1 font-mono text-[8px] opacity-60">{statusLabel[node.status] ?? node.status} · {node.date}</p>
            </div>); })}
          {!nodes.length && <p className="p-6 text-xs text-zinc-500">尚無決策節點——按「新增決策節點」放第一張，或在 docs\decisions\ 放 ADR-*.md。</p>}
        </div>
      </div>
    </div>
    <aside className="border-l border-zinc-800 pl-4">
      {formOpen ? <form onSubmit={submit} className="space-y-2 text-[11px]">
        <div className="flex items-center justify-between"><h3 className="font-semibold">新增決策節點</h3><button type="button" onClick={() => setFormOpen(false)}><X size={13}/></button></div>
        <input value={title} onChange={(event) => setTitle(event.target.value)} placeholder="決策標題（必填）" className="w-full border border-zinc-700 bg-zinc-900 px-2 py-1.5 outline-none focus:border-cyan-600"/>
        <select value={status} onChange={(event) => setStatus(event.target.value)} className="w-full border border-zinc-700 bg-zinc-900 px-2 py-1.5">
          <option value="proposed">proposed（分叉候選）</option><option value="accepted">accepted（已定案）</option><option value="superseded">superseded（已被取代）</option>
        </select>
        <textarea value={bodyText} onChange={(event) => setBodyText(event.target.value)} placeholder="處境／決定／回頭條件（可稍後補進 md 檔）" rows={5} className="w-full border border-zinc-700 bg-zinc-900 px-2 py-1.5 outline-none focus:border-cyan-600"/>
        <p className="text-[10px] text-zinc-500">連到既有節點：</p>
        <div className="max-h-28 space-y-1 overflow-y-auto">{nodes.map((node) => <label key={node.id} className="flex items-center gap-2 text-[10px]"><input type="checkbox" checked={formLinks.includes(node.id)} onChange={(event) => setFormLinks((value) => event.target.checked ? [...value, node.id] : value.filter((item) => item !== node.id))}/>{node.title}</label>)}</div>
        <button disabled={!title.trim()} className="w-full border border-cyan-700 bg-cyan-900 py-1.5 text-cyan-100 disabled:opacity-40">建立（寫入 ADR 檔案）</button>
      </form> : chosen ? <>
        <h3 className="text-xs font-semibold">{chosen.title}</h3>
        <p className="mt-1 font-mono text-[9px] text-zinc-500">{chosen.id} · {statusLabel[chosen.status] ?? chosen.status}</p>
        {chosen.status !== "landed" && <div className="mt-2 space-y-1 border border-zinc-800 bg-zinc-900 p-2 text-[10px]">
          <p className="text-zinc-400">驗證確認</p>
          <input value={evidence} onChange={(event) => setEvidence(event.target.value)} placeholder="落地證據（檔案路徑/工單 ID，選填）" className="w-full border border-zinc-700 bg-zinc-950 px-2 py-1 text-[10px] outline-none focus:border-cyan-600"/>
          <div className="flex gap-2">
            {chosen.status === "proposed" && <button onClick={() => void promote("accepted")} className="border border-amber-700 bg-amber-950 px-2 py-1 text-amber-200">標記定案</button>}
            <button onClick={() => void promote("landed")} className="flex items-center gap-1 border border-cyan-700 bg-cyan-950 px-2 py-1 text-cyan-200"><CheckCircle2 size={11}/>標記落地</button>
            {chosen.status !== "proposed" && <button onClick={() => void promote("superseded")} className="border border-zinc-700 px-2 py-1 text-zinc-400">標記取代</button>}
          </div>
        </div>}
        <div className="mt-2 flex items-center gap-2 text-[10px]">
          <Link2 size={11} className="text-zinc-500"/>
          <select value={linkTarget} onChange={(event) => setLinkTarget(event.target.value)} className="min-w-0 flex-1 border border-zinc-700 bg-zinc-900 px-1 py-1">
            <option value="">連線到…</option>
            {nodes.filter((node) => node.id !== chosen.id).map((node) => <option key={node.id} value={node.id}>{node.title}</option>)}
          </select>
          <button onClick={() => void connect()} disabled={!linkTarget} className="border border-zinc-700 px-2 py-1 disabled:opacity-40">連線</button>
        </div>
        <pre className="mt-3 max-h-[430px] overflow-auto whitespace-pre-wrap break-words border border-zinc-800 bg-black/30 p-3 text-[10px] text-zinc-300">{chosen.body}</pre>
      </> : <p className="text-[10px] text-zinc-600">點擊節點查看全文與連線；新節點會直接寫成 docs\decisions\ 的 ADR markdown 檔，Obsidian 同步可讀。</p>}
    </aside>
  </div>;
}

export default function DecisionMap() {
  const [mode, setMode] = useState<"strategy" | "trail">("strategy");
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
      <div className="mb-4 flex items-center gap-3">
        <GitBranch size={15} className="text-cyan-400" /><h2 className="text-sm font-semibold">Decision path</h2>
        <nav className="flex items-center gap-1 border border-zinc-800 bg-zinc-900 p-1">
          <button onClick={() => setMode("strategy")} className={`flex items-center gap-1 px-2 py-1 text-[11px] ${mode === "strategy" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><Map size={11}/>戰略地圖</button>
          <button onClick={() => setMode("trail")} className={`flex items-center gap-1 px-2 py-1 text-[11px] ${mode === "trail" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><Search size={11}/>工單軌跡</button>
        </nav>
      </div>
      {mode === "strategy" && <StrategyMap/>}
      {mode === "trail" && <>
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
                <div className="flex gap-3"><strong className="text-zinc-200">{item.actor} / {item.action}</strong><span className="font-mono text-zinc-500">{item.ts}</span><span className="ml-auto text-zinc-400">{item.result}</span></div>
                <div className="mt-2 grid gap-1 font-mono text-zinc-500 md:grid-cols-2"><p className="truncate">script: {item.script ?? "unknown"}</p><p className="truncate">runtime: {item.runtime_id}</p><p className="truncate">input: {item.input_ref ?? "none"}</p><p className="truncate">output: {item.output_ref ?? "none"}</p><p className="truncate md:col-span-2">next: {item.next_step ?? "none"}</p></div>
              </article>
            </div>
          ))}
          {!events.length && <p className="text-xs text-zinc-500">Enter an exact dispatch ID to reconstruct its recorded path.</p>}
        </div>
      </>}
    </section>
  );
}
