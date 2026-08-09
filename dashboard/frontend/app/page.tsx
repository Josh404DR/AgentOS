"use client";

import { useEffect, useState } from "react";
import { Bot, GitBranch, LayoutDashboard, ClipboardList, BookOpen, CalendarDays } from "lucide-react";
import GovernanceStatus from "@/components/GovernanceStatus";
import RuntimeStatus from "@/components/RuntimeStatus";
import UsagePanel from "@/components/UsagePanel";
import EventTimeline from "@/components/EventTimeline";
import StatusAssistant from "@/components/StatusAssistant";
import TaskWorkspace from "@/components/TaskWorkspace";
import DecisionMap from "@/components/DecisionMap";
import OwnerSession from "@/components/OwnerSession";
import KnowledgeWorkspace from "@/components/KnowledgeWorkspace";
import TodayWorkspace from "@/components/TodayWorkspace";
import ApprovalQueue from "@/components/ApprovalQueue";

type Tab = "today" | "knowledge" | "dashboard" | "tasks" | "decisions";

export default function Home() {
  const [tab, setTab] = useState<Tab>("dashboard");
  const [knowledgeNode, setKnowledgeNode] = useState("");
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const requested = params.get("tab");
    if (["today", "knowledge", "dashboard", "tasks", "decisions"].includes(requested ?? "")) setTab(requested as Tab);
    setKnowledgeNode(params.get("node") ?? "");
  }, []);
  return (
    <main className="flex min-h-screen flex-col bg-zinc-950 text-zinc-100">
      <header className="flex shrink-0 flex-wrap items-center gap-3 border-b border-zinc-800 px-4 py-3 sm:flex-nowrap sm:px-5">
        <div className="flex h-7 w-7 shrink-0 items-center justify-center bg-cyan-700"><Bot size={14} /></div>
        <div className="shrink-0">
          <h1 className="text-sm font-bold">AgentOS</h1>
          <p className="text-[10px] text-zinc-500">公開唯讀區 / Public Read Plane</p>
        </div>
        <nav className="order-3 flex w-full items-center gap-1 border border-zinc-800 bg-zinc-900 p-1 sm:order-none sm:ml-4 sm:w-auto sm:shrink-0" aria-label="Primary views">
          <button onClick={() => setTab("today")} className={`flex flex-1 items-center justify-center gap-1.5 px-2 py-1 text-xs sm:flex-none sm:px-3 ${tab === "today" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><CalendarDays size={12} />今日</button>
          <button onClick={() => setTab("knowledge")} className={`flex flex-1 items-center justify-center gap-1.5 px-2 py-1 text-xs sm:flex-none sm:px-3 ${tab === "knowledge" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><BookOpen size={12} />知識</button>
          <button onClick={() => setTab("dashboard")} className={`flex flex-1 items-center justify-center gap-1.5 px-2 py-1 text-xs sm:flex-none sm:px-3 ${tab === "dashboard" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><LayoutDashboard size={12} />Dashboard</button>
          <button onClick={() => setTab("tasks")} className={`flex flex-1 items-center justify-center gap-1.5 px-2 py-1 text-xs sm:flex-none sm:px-3 ${tab === "tasks" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><ClipboardList size={12} />Tasks</button>
          <button onClick={() => setTab("decisions")} className={`flex flex-1 items-center justify-center gap-1.5 px-2 py-1 text-xs sm:flex-none sm:px-3 ${tab === "decisions" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><GitBranch size={12} />Decisions</button>
        </nav>
        <div className="ml-auto flex shrink-0 items-center gap-3"><span className="hidden text-[10px] text-zinc-500 xl:inline">擁有者驗證控制區 / Owner-Authenticated Control Plane</span><OwnerSession /><GovernanceStatus compact /></div>
      </header>

      {tab === "dashboard" && (
        <div className="flex flex-1 flex-col">
          <RuntimeStatus />
          <div className="grid flex-1 grid-cols-1 xl:grid-cols-[minmax(0,3fr)_minmax(320px,1fr)]">
            <div className="grid grid-rows-[auto_minmax(420px,1fr)] gap-3 border-r border-zinc-800 p-4">
              <UsagePanel />
              <div className="min-h-0"><EventTimeline /></div>
            </div>
            <div className="h-[420px] border-t border-zinc-800 xl:sticky xl:top-0 xl:h-screen xl:border-t-0"><StatusAssistant /></div>
          </div>
        </div>
      )}
      {tab === "tasks" && <div className="min-h-0 flex-1"><TaskWorkspace /></div>}
      {tab === "decisions" && <div className="min-h-0 flex-1"><DecisionMap /></div>}
      {tab === "today" && (
        <div className="grid min-h-0 flex-1 grid-cols-1 xl:grid-cols-[minmax(0,3fr)_minmax(360px,1fr)]">
          <TodayWorkspace onOpenKnowledge={(id) => { setKnowledgeNode(id); setTab("knowledge"); }} />
          <aside className="min-h-[360px] border-t border-zinc-800 xl:border-l xl:border-t-0">
            <ApprovalQueue />
          </aside>
        </div>
      )}
      {tab === "knowledge" && <div className="min-h-0 flex-1"><KnowledgeWorkspace initialNode={knowledgeNode} /></div>}
    </main>
  );
}
