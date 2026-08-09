"use client";

import { useEffect, useMemo, useState } from "react";
import { fetchToday } from "@/lib/api";

const READ_KEY = "agentos-dashboard-read-completions-v1";

export default function TodayWorkspace({ onOpenKnowledge }: { onOpenKnowledge: (id: string) => void }) {
  const [data, setData] = useState<any>(null);
  const [error, setError] = useState("");
  const [readIds, setReadIds] = useState<string[]>([]);

  useEffect(() => {
    fetchToday().then(setData).catch((e) => setError(String(e)));
    try { setReadIds(JSON.parse(window.localStorage.getItem(READ_KEY) ?? "[]")); } catch { setReadIds([]); }
  }, []);

  const unreadCompleted = useMemo(
    () => (data?.recent_completed ?? []).filter((item: any) => !readIds.includes(item.dispatch_id)),
    [data, readIds],
  );

  function markRead(dispatchId: string) {
    const next = Array.from(new Set([...readIds, dispatchId]));
    setReadIds(next);
    window.localStorage.setItem(READ_KEY, JSON.stringify(next));
  }

  const taskList = (title: string, items: any[]) => (
    <section className="border border-zinc-800 p-4">
      <h3 className="mb-3 font-semibold">{title}</h3>
      {items.length ? items.map((item: any) => (
        <div key={item.id} className="mb-2 border-b border-zinc-800 pb-2 text-xs">
          <span className="text-zinc-500">{item.normalized_status}</span> · {item.title}
        </div>
      )) : <p className="text-xs text-zinc-600">目前沒有項目</p>}
    </section>
  );

  return (
    <div className="p-5">
      <h2 className="text-xl font-bold">今日</h2>
      <p className="mb-5 text-xs text-zinc-500">未讀完成、待處理事項、候選與最近知識；不依賴 NotebookLM。</p>
      {error && <p className="text-red-400">{error}</p>}
      <div className="grid gap-4 lg:grid-cols-2">
        <section className="border border-zinc-800 p-4">
          <h3 className="mb-3 font-semibold">未讀完成</h3>
          {unreadCompleted.length ? unreadCompleted.map((item: any) => (
            <div key={item.dispatch_id} className="mb-2 flex items-start justify-between gap-2 border-b border-zinc-800 pb-2 text-xs">
              <span>{item.title}</span>
              <button onClick={() => markRead(item.dispatch_id)} className="shrink-0 border border-zinc-700 px-2 py-1 text-zinc-400">標為已讀</button>
            </div>
          )) : <p className="text-xs text-zinc-600">目前沒有未讀完成項</p>}
        </section>
        {taskList("需要 Josh", data?.needs_josh ?? [])}
        {taskList("失敗可恢復", data?.recoverable_failures ?? [])}
        <section className="border border-zinc-800 p-4">
          <h3 className="mb-3 font-semibold">待處理 Feedback</h3>
          {(data?.pending_feedback ?? []).length ? data.pending_feedback.map((item: any) => (
            <button key={item.event_id} onClick={() => onOpenKnowledge(item.node_id)} className="mb-2 block w-full border-b border-zinc-800 pb-2 text-left text-xs hover:text-cyan-300">{item.content}</button>
          )) : <p className="text-xs text-zinc-600">目前沒有待處理 feedback</p>}
        </section>
        <section className="border border-zinc-800 p-4">
          <h3 className="mb-3 font-semibold">草稿 Candidate</h3>
          {(data?.knowledge_candidates ?? []).length ? data.knowledge_candidates.map((item: any) => (
            <button key={item.candidate_id} onClick={() => onOpenKnowledge(item.node_id)} className="mb-2 block w-full border-b border-zinc-800 pb-2 text-left text-xs hover:text-cyan-300">{item.title || item.candidate_id}</button>
          )) : <p className="text-xs text-zinc-600">目前沒有 candidate</p>}
        </section>
        <section className="border border-zinc-800 p-4">
          <h3 className="mb-3 font-semibold">最近知識</h3>
          {(data?.knowledge_nodes ?? []).map((item: any) => (
            <button key={item.dispatch_id} onClick={() => onOpenKnowledge(item.dispatch_id)} className="mb-2 block w-full border-b border-zinc-800 pb-2 text-left text-xs hover:text-cyan-300">{item.title}</button>
          ))}
        </section>
      </div>
    </div>
  );
}
