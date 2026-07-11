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
    <main className="flex h-screen min-h-0 flex-col overflow-hidden bg-zinc-950 text-zinc-100">
      <header className="flex shrink-0 items-center gap-3 overflow-x-auto border-b border-zinc-800 px-5 py-3">
        <div className="flex h-7 w-7 shrink-0 items-center justify-center bg-cyan-700"><Bot size={14} /></div>
        <div className="shrink-0">
          <h1 className="text-sm font-bold">AgentOS</h1>
          <p className="text-[10px] text-zinc-500">Operational console</p>
        </div>
        <nav className="ml-4 flex shrink-0 items-center gap-1 border border-zinc-800 bg-zinc-900 p-1" aria-label="Primary views">
          <button onClick={() => setTab("dashboard")} className={`flex items-center gap-1.5 px-3 py-1 text-xs ${tab === "dashboard" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><LayoutDashboard size={12} />Dashboard</button>
          <button onClick={() => setTab("tasks")} className={`flex items-center gap-1.5 px-3 py-1 text-xs ${tab === "tasks" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><ClipboardList size={12} />Task workspace</button>
          <button onClick={() => setTab("decisions")} className={`flex items-center gap-1.5 px-3 py-1 text-xs ${tab === "decisions" ? "bg-zinc-700 text-white" : "text-zinc-500"}`}><GitBranch size={12} />Decision path</button>
        </nav>
        <div className="ml-auto shrink-0"><GovernanceStatus compact /></div>
      </header>

      {tab === "dashboard" && (
        <div className="flex min-h-0 flex-1 flex-col">
          <RuntimeStatus />
          <div className="grid min-h-0 flex-1 grid-cols-1 xl:grid-cols-[minmax(0,3fr)_minmax(320px,1fr)]">
            <div className="grid min-h-0 grid-rows-[auto_minmax(0,1fr)] gap-3 overflow-hidden border-r border-zinc-800 p-4">
              <UsagePanel />
              <div className="min-h-0"><EventTimeline /></div>
            </div>
            <div className="min-h-[320px] border-t border-zinc-800 xl:min-h-0 xl:border-t-0"><StatusAssistant /></div>
          </div>
        </div>
      )}
      {tab === "tasks" && <div className="min-h-0 flex-1"><TaskWorkspace /></div>}
      {tab === "decisions" && <div className="min-h-0 flex-1"><DecisionMap /></div>}
    </main>
  );
}
