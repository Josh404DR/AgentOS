"use client";

import { useEffect, useRef, useState } from "react";
import { wsUrl } from "@/lib/api";
import { Circle, Terminal } from "lucide-react";

interface LogLine {
  type: "history" | "new" | "error";
  line: string;
}

const SOURCES = [
  { id: "hermes", label: "Hermes", color: "text-purple-300" },
  { id: "codex", label: "Codex CLI", color: "text-emerald-300" },
  { id: "claude", label: "Claude CLI", color: "text-orange-300" },
] as const;

function AgentTerminal({
  id,
  label,
  color,
}: {
  id: string;
  label: string;
  color: string;
}) {
  const [lines, setLines] = useState<LogLine[]>([]);
  const [connected, setConnected] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    setLines([]);
    const ws = new WebSocket(wsUrl(`/ws/logs/${id}`));
    ws.onopen = () => setConnected(true);
    ws.onclose = () => setConnected(false);
    ws.onerror = () => setConnected(false);
    ws.onmessage = (event) => {
      const message = JSON.parse(event.data) as {
        type: LogLine["type"];
        line?: string;
        message?: string;
      };
      setLines((current) => [
        ...current.slice(-300),
        {
          type: message.type,
          line: message.line ?? message.message ?? "",
        },
      ]);
    };
    return () => ws.close();
  }, [id]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [lines]);

  return (
    <section className="min-w-0 flex flex-col bg-zinc-950 border border-zinc-800 rounded-lg overflow-hidden">
      <header className="flex items-center gap-2 px-3 py-2 border-b border-zinc-800">
        <Circle
          size={7}
          className={
            connected
              ? "text-emerald-400 fill-emerald-400"
              : "text-zinc-600 fill-zinc-600"
          }
        />
        <span className={`text-xs font-semibold ${color}`}>{label}</span>
        <span className="ml-auto text-[10px] text-zinc-600">
          {connected ? "已連線" : "未連線"}
        </span>
      </header>
      <div className="flex-1 min-h-[150px] max-h-[280px] overflow-y-auto p-3 font-mono text-[10px] leading-relaxed">
        {lines.length === 0 && (
          <p className="text-zinc-600">等待最新輸出…</p>
        )}
        {lines.map((item, index) => (
          <div
            key={`${index}-${item.line}`}
            className={
              item.type === "new"
                ? "text-emerald-300"
                : item.type === "error"
                  ? "text-red-400"
                  : "text-zinc-400"
            }
          >
            {item.line}
          </div>
        ))}
        <div ref={bottomRef} />
      </div>
    </section>
  );
}

export default function LiveLogs() {
  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-xl flex flex-col overflow-hidden h-full min-h-[220px]">
      <div className="flex items-center gap-2 px-5 py-3 border-b border-zinc-800">
        <Terminal size={16} className="text-emerald-400" />
        <h2 className="text-sm font-semibold text-zinc-200 tracking-wide">
          即時紀錄
        </h2>
        <span className="text-[10px] text-zinc-500">
          Hermes · Codex CLI · Claude CLI
        </span>
      </div>
      <div className="grid grid-cols-1 xl:grid-cols-3 gap-2 p-2 flex-1">
        {SOURCES.map((source) => (
          <AgentTerminal key={source.id} {...source} />
        ))}
      </div>
    </div>
  );
}
