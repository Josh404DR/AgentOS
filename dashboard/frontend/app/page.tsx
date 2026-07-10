"use client";

import { useState } from "react";
import UsagePanel from "@/components/UsagePanel";
import WorkTrail from "@/components/WorkTrail";
import LiveLogs from "@/components/LiveLogs";
import TaskBoard from "@/components/TaskBoard";
import HermesChat from "@/components/HermesChat";
import DecisionMap from "@/components/DecisionMap";
import GovernanceStatus from "@/components/GovernanceStatus";
import TaskUniverse from "@/components/TaskUniverse";
import WorkflowSupervisor from "@/components/WorkflowSupervisor";
import ApprovalQueue from "@/components/ApprovalQueue";
import RuntimeStatus from "@/components/RuntimeStatus";
import { Bot, GitBranch, LayoutDashboard, Radar, UserCheck, Workflow } from "lucide-react";

type Tab = "dashboard" | "decisions" | "tasks" | "supervisor" | "approvals";

export default function Home() {
  const [tab, setTab] = useState<Tab>("dashboard");

  return (
    <main className="h-screen bg-zinc-950 text-zinc-100 flex flex-col overflow-hidden">
      {/* Header */}
      <header className="flex items-center gap-3 px-5 py-3 border-b border-zinc-800 flex-shrink-0">
        <div className="w-7 h-7 rounded-lg bg-purple-600 flex items-center justify-center">
          <Bot size={14} className="text-white" />
        </div>
        <div>
          <h1 className="text-sm font-bold tracking-tight">AgentOS Dashboard</h1>
          <p className="text-[10px] text-zinc-500 leading-none">Hermes · Codex · Claude</p>
        </div>

        {/* Tab switcher */}
        <div className="ml-6 flex items-center gap-1 bg-zinc-900 rounded-lg p-1 border border-zinc-800">
          <button
            onClick={() => setTab("dashboard")}
            className={`flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium transition-all ${
              tab === "dashboard"
                ? "bg-zinc-700 text-zinc-100"
                : "text-zinc-500 hover:text-zinc-300"
            }`}
          >
            <LayoutDashboard size={12} />
            監控
          </button>
          <button
            onClick={() => setTab("decisions")}
            className={`flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium transition-all ${
              tab === "decisions"
                ? "bg-zinc-700 text-zinc-100"
                : "text-zinc-500 hover:text-zinc-300"
            }`}
          >
            <GitBranch size={12} />
            決策路徑
          </button>
          <button
            onClick={() => setTab("tasks")}
            className={`flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium transition-all ${
              tab === "tasks"
                ? "bg-zinc-700 text-zinc-100"
                : "text-zinc-500 hover:text-zinc-300"
            }`}
          >
            <Radar size={12} />
            工單宇宙
          </button>
          <button
            onClick={() => setTab("supervisor")}
            className={`flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium transition-all ${
              tab === "supervisor"
                ? "bg-zinc-700 text-zinc-100"
                : "text-zinc-500 hover:text-zinc-300"
            }`}
          >
            <Workflow size={12} />
            流程監工
          </button>
          <button
            onClick={() => setTab("approvals")}
            className={`flex items-center gap-1.5 px-3 py-1 rounded-md text-xs font-medium transition-all ${
              tab === "approvals"
                ? "bg-zinc-700 text-zinc-100"
                : "text-zinc-500 hover:text-zinc-300"
            }`}
          >
            <UserCheck size={12} />
            待我核准
          </button>
        </div>

        <div className="ml-auto flex items-center gap-2">
          <GovernanceStatus compact />
          <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
          <span className="text-xs text-zinc-400">即時</span>
        </div>
      </header>

      {tab === "dashboard" && <RuntimeStatus />}

      {/* ── Tab: Dashboard ── */}
      {tab === "dashboard" && (
        <div className="flex flex-1 overflow-hidden gap-0">

          {/* LEFT: Monitoring 60% */}
          <div className="flex flex-col flex-[3] overflow-hidden border-r border-zinc-800 p-4 gap-3 min-w-0">
            <div className="grid grid-cols-5 gap-3 flex-shrink-0">
              <div className="col-span-2"><UsagePanel /></div>
              <div className="col-span-3"><TaskBoard /></div>
            </div>
            <div className="flex-shrink-0"><WorkTrail /></div>
            <div className="flex-1 min-h-0"><LiveLogs /></div>
          </div>

          {/* RIGHT: Hermes Chat 40% */}
          <div className="flex flex-col flex-[2] min-w-0 min-h-0">
            <HermesChat />
          </div>
        </div>
      )}

      {/* ── Tab: Decision Map ── */}
      {tab === "decisions" && (
        <div className="flex-1 overflow-hidden">
          <DecisionMap />
        </div>
      )}

      {tab === "tasks" && (
        <div className="flex-1 overflow-hidden">
          <TaskUniverse />
        </div>
      )}

      {tab === "supervisor" && (
        <div className="flex-1 overflow-hidden">
          <WorkflowSupervisor />
        </div>
      )}

      {tab === "approvals" && (
        <div className="flex-1 overflow-hidden">
          <ApprovalQueue />
        </div>
      )}
    </main>
  );
}
