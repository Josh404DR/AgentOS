"use client";

import { useState } from "react";
import { ClipboardList, GitBranch, ShieldAlert, Workflow, History } from "lucide-react";
import TaskBoard from "@/components/TaskBoard";
import TaskUniverse from "@/components/TaskUniverse";
import ApprovalQueue from "@/components/ApprovalQueue";
import WorkflowSupervisor from "@/components/WorkflowSupervisor";
import EventTimeline from "@/components/EventTimeline";
import FailurePath from "@/components/FailurePath";

type View = "list" | "dependencies" | "escalations" | "supervision" | "events" | "failures";
const views: Array<{ id: View; label: string; icon: typeof ClipboardList }> = [
  { id: "list", label: "List & outputs", icon: ClipboardList },
  { id: "dependencies", label: "Dependencies", icon: GitBranch },
  { id: "escalations", label: "Escalations", icon: ShieldAlert },
  { id: "supervision", label: "Supervision", icon: Workflow },
  { id: "events", label: "Event trail", icon: History },
  { id: "failures", label: "Failure path", icon: ShieldAlert },
];

export default function TaskWorkspace() {
  const [view, setView] = useState<View>("list");
  return (
    <section className="flex h-full min-h-0 flex-col bg-zinc-950">
      <nav className="flex shrink-0 gap-1 border-b border-zinc-800 px-4 py-2" aria-label="Task workspace views">
        {views.map(({ id, label, icon: Icon }) => (
          <button key={id} onClick={() => setView(id)} className={`flex items-center gap-1.5 px-3 py-1.5 text-xs ${view === id ? "bg-zinc-700 text-white" : "text-zinc-500 hover:bg-zinc-900 hover:text-zinc-200"}`}>
            <Icon size={12} />{label}
          </button>
        ))}
      </nav>
      <div className="min-h-0 flex-1 overflow-auto p-4">
        {view === "list" && <TaskBoard />}
        {view === "dependencies" && <div className="h-full min-h-[560px]"><TaskUniverse /></div>}
        {view === "escalations" && <ApprovalQueue />}
        {view === "supervision" && <WorkflowSupervisor />}
        {view === "events" && <div className="h-full min-h-[480px]"><EventTimeline /></div>}
        {view === "failures" && <div className="h-full min-h-[480px]"><FailurePath /></div>}
      </div>
    </section>
  );
}
