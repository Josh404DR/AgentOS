"use client";

import { useState } from "react";
import { Bot, GitBranch, LayoutDashboard, ClipboardList } from "lucide-react";
import GovernanceStatus from "@/components/GovernanceStatus";
import RuntimeStatus from "@/components/RuntimeStatus";
import UsagePanel from "@/components/UsagePanel";
import EventTimeline from "@/components/EventTimeline";
import StatusAssistant from "@/components/StatusAssistant";
import TaskWorkspace from "@/components/TaskWorkspace";
import DecisionMap from "@/components/DecisionMap";

type Tab = "dashboard" | "tasks" | "decisions";

export default function Home() {
  const [tab, setTab] = useState<Tab>("dashboard");
  return (
    <main className="flex min-h-screen flex-col bg-zinc-950 text-zinc-100 xl:h-screen xl:min-h-0 xl:overflow-hidden">
      <header className="flex shrink-0 flex-wrap items-center gap-3 border-b border-zinc-800 px-4 py-3 sm:flex-nowrap sm:px-5">
        <div className="flex h-7 w-7 shrink-0 items-center justify-center bg-cyan-700"><Bot size={14} /></div>
        <div className="shrink-0">
          <h1 className="text-sm font-bold">AgentOS</h1>
          <p className="text-[10px] text-zinc-500">Operational console</p>
        </div>
        <nav className="order-3 flex w-full items-center gap-1 border border-zinc-800 bg-zinc-900 p-1 sm:order-none sm:ml-4 sm:w-auto sm:shrink-0" aria-label="Primary views">
          <button onClick={() => setTab("dashboard")} className={`flex flex-1 items-center justify-center gap-1.5 px-2 py-1 text-xs sm:flex-none sm:px-3 ${tab === "dashboard" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><LayoutDashboard size={12} />Dashboard</button>
          <button onClick={() => setTab("tasks")} className={`flex flex-1 items-center justify-center gap-1.5 px-2 py-1 text-xs sm:flex-none sm:px-3 ${tab === "tasks" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><ClipboardList size={12} />Tasks</button>
          <button onClick={() => setTab("decisions")} className={`flex flex-1 items-center justify-center gap-1.5 px-2 py-1 text-xs sm:flex-none sm:px-3 ${tab === "decisions" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><GitBranch size={12} />Decisions</button>
        </nav>
        <div className="ml-auto shrink-0"><GovernanceStatus compact /></div>
      </header>

      {tab === "dashboard" && (
        <div className="flex flex-1 flex-col xl:min-h-0">
          <RuntimeStatus />
          <div className="grid flex-1 grid-cols-1 xl:min-h-0 xl:grid-cols-[minmax(0,3fr)_minmax(320px,1fr)]">
            <div className="grid grid-rows-[auto_minmax(420px,1fr)] gap-3 border-r border-zinc-800 p-4 xl:min-h-0 xl:grid-rows-[auto_minmax(0,1fr)] xl:overflow-hidden">
              <UsagePanel />
              <div className="min-h-0"><EventTimeline /></div>
            </div>
            <div className="h-[420px] border-t border-zinc-800 xl:h-auto xl:min-h-0 xl:border-t-0"><StatusAssistant /></div>
          </div>
        </div>
      )}
      {tab === "tasks" && <div className="min-h-0 flex-1"><TaskWorkspace /></div>}
      {tab === "decisions" && <div className="min-h-0 flex-1"><DecisionMap /></div>}
    </main>
  );
}
