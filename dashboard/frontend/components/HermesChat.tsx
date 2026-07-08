"use client";

import { useEffect, useRef, useState } from "react";
import { wsUrl } from "@/lib/api";

const BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

interface Message {
  id: string;
  role: "user" | "assistant" | "system";
  content: string;
  ts: number;
  source?: string;
  delta_tokens?: number;
}

interface ContextData {
  pct: number;
  used: number;
  total: number;
  input?: number;
  output?: number;
  cache?: number;
}

function fmt(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}K`;
  return String(n);
}

function ContextBar({ ctx }: { ctx: ContextData }) {
  const pct = ctx.pct;
  const color = pct >= 90 ? "bg-red-500" : pct >= 70 ? "bg-yellow-400" : "bg-blue-500";
  return (
    <div className="px-4 py-2 border-b border-zinc-800 bg-zinc-950">
      <div className="flex items-center justify-between text-[11px] text-zinc-400 mb-1">
        <span className="font-medium text-zinc-300">上下文使用量</span>
        <span className="font-mono">
          {fmt(ctx.used)} / {fmt(ctx.total)} Tokens
          <span className={`ml-2 font-semibold ${pct >= 90 ? "text-red-400" : pct >= 70 ? "text-yellow-400" : "text-blue-400"}`}>
            {pct}% Full
          </span>
        </span>
      </div>
      <div className="flex gap-0.5 h-1.5 rounded-full overflow-hidden bg-zinc-800">
        {/* Segmented bar: input / output / cache */}
        {ctx.total > 0 && (
          <>
            <div className="bg-blue-500 h-full" style={{ width: `${((ctx.input ?? 0) / ctx.total) * 100}%` }} title="Input" />
            <div className="bg-purple-500 h-full" style={{ width: `${((ctx.output ?? 0) / ctx.total) * 100}%` }} title="Output" />
            <div className="bg-zinc-500 h-full" style={{ width: `${((ctx.cache ?? 0) / ctx.total) * 100}%` }} title="Cache" />
          </>
        )}
      </div>
      <div className="flex gap-3 mt-1 text-[9px] text-zinc-600">
        <span><span className="inline-block w-2 h-2 rounded-sm bg-blue-500 mr-1" />輸入 {fmt(ctx.input ?? 0)}</span>
        <span><span className="inline-block w-2 h-2 rounded-sm bg-purple-500 mr-1" />輸出 {fmt(ctx.output ?? 0)}</span>
        <span><span className="inline-block w-2 h-2 rounded-sm bg-zinc-500 mr-1" />快取 {fmt(ctx.cache ?? 0)}</span>
      </div>
    </div>
  );
}

export default function HermesChat() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [ctx, setCtx] = useState<ContextData>({ pct: 0, used: 0, total: 200000 });
  const bottomRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  // Load context on mount and poll
  useEffect(() => {
    const loadCtx = () =>
      fetch(`${BASE}/api/context`).then(r => r.json()).then(setCtx).catch(() => {});
    loadCtx();
    const t = setInterval(loadCtx, 15_000);
    return () => clearInterval(t);
  }, []);

  // Scroll to bottom on new messages
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const send = async () => {
    const text = input.trim();
    if (!text || loading) return;

    const userMsg: Message = {
      id: Date.now().toString(),
      role: "user",
      content: text,
      ts: Date.now(),
    };
    setMessages(prev => [...prev, userMsg]);
    setInput("");
    setLoading(true);

    try {
      const res = await fetch(`${BASE}/api/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: text }),
      });
      const data = await res.json();

      if (data.error && !data.response) {
        setMessages(prev => [...prev, {
          id: Date.now().toString() + "e",
          role: "system",
          content: `⚠️ ${data.error}`,
          ts: Date.now(),
        }]);
      } else {
        setMessages(prev => [...prev, {
          id: Date.now().toString() + "r",
          role: "assistant",
          content: data.response ?? "(empty)",
          ts: Date.now(),
          delta_tokens: data.delta_tokens,
        }]);
        if (data.context) setCtx(data.context);
      }
    } catch (e) {
      setMessages(prev => [...prev, {
        id: Date.now().toString() + "err",
        role: "system",
        content: "⚠️ 連線失敗",
        ts: Date.now(),
      }]);
    } finally {
      setLoading(false);
      inputRef.current?.focus();
    }
  };

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      send();
    }
  };

  return (
    <div className="flex flex-col h-full bg-zinc-900 border border-zinc-800 rounded-xl overflow-hidden">
      {/* Header */}
      <div className="flex items-center gap-2 px-4 py-3 border-b border-zinc-800 flex-shrink-0">
        <div className="w-2 h-2 rounded-full bg-purple-400" />
        <h2 className="text-sm font-semibold text-zinc-200 tracking-wide uppercase">Hermes</h2>
        <span className="text-[10px] bg-zinc-800 text-zinc-400 px-1.5 py-0.5 rounded font-mono">Lite · Groq</span>
        {loading
          ? <span className="ml-auto text-xs text-purple-400 animate-pulse">思考中…</span>
          : <span className="ml-auto text-[10px] text-zinc-600">無 tool schemas · 直接 API</span>
        }
      </div>

      {/* Context bar */}
      <ContextBar ctx={ctx} />

      {/* Messages */}
      <div className="flex-1 overflow-y-auto px-4 py-3 space-y-3">
        {messages.length === 0 && (
          <p className="text-zinc-600 text-sm text-center mt-8">輸入訊息和 Hermes 對話</p>
        )}
        {messages.map(msg => (
          <div key={msg.id} className={`flex ${msg.role === "user" ? "justify-end" : "justify-start"}`}>
            <div
              className={`max-w-[85%] rounded-xl px-3 py-2 text-sm leading-relaxed whitespace-pre-wrap ${
                msg.role === "user"
                  ? "bg-purple-700 text-white"
                  : msg.role === "system"
                  ? "bg-zinc-800 text-red-400 text-xs"
                  : "bg-zinc-800 text-zinc-100"
              }`}
            >
              {msg.content}
              {msg.delta_tokens != null && msg.delta_tokens > 0 && (
                <div className="text-[10px] text-zinc-500 mt-1 text-right">
                  +{fmt(msg.delta_tokens)} tokens
                </div>
              )}
            </div>
          </div>
        ))}
        {loading && (
          <div className="flex justify-start">
            <div className="bg-zinc-800 rounded-xl px-4 py-2">
              <span className="flex gap-1">
                {[0, 1, 2].map(i => (
                  <span
                    key={i}
                    className="w-1.5 h-1.5 bg-purple-400 rounded-full animate-bounce"
                    style={{ animationDelay: `${i * 0.15}s` }}
                  />
                ))}
              </span>
            </div>
          </div>
        )}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="border-t border-zinc-800 p-3 flex-shrink-0">
        <div className="flex gap-2 items-end">
          <textarea
            ref={inputRef}
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={onKeyDown}
            placeholder="輸入訊息… (Enter 送出, Shift+Enter 換行)"
            rows={2}
            disabled={loading}
            className="flex-1 bg-zinc-800 text-zinc-100 text-sm rounded-lg px-3 py-2 resize-none outline-none focus:ring-1 focus:ring-purple-600 placeholder-zinc-600 disabled:opacity-50"
          />
          <button
            onClick={send}
            disabled={loading || !input.trim()}
            className="px-4 py-2 bg-purple-600 hover:bg-purple-500 disabled:opacity-40 disabled:cursor-not-allowed text-white text-sm font-semibold rounded-lg transition self-end"
          >
            送出
          </button>
        </div>
      </div>
    </div>
  );
}
