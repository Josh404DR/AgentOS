"use client";

import { useEffect, useState } from "react";
import { fetchUsage } from "@/lib/api";
import { Zap, AlertTriangle, Clock, Calendar, Cpu } from "lucide-react";

interface WindowData {
  session_count: number;
  input_tokens: number;
  output_tokens: number;
  cache_read: number;
  reasoning_tokens?: number;
  est_cost: number;
}

interface UsageData {
  total?: { input_tokens: number; output_tokens: number; cache_read: number; session_count: number; est_cost: number };
  window_5h?: WindowData;
  window_7d?: WindowData;
  recent_sessions?: Array<{ id: string; model: string; input_tokens: number; output_tokens: number; started_at: number }>;
  current_model?: string;
  error?: string;
}

// Groq free plan limits (approximate, conservative)
const LIMIT_5H = 500_000;    // Groq rate limits are much lower
const LIMIT_7D = 3_000_000;

function ProgressBar({ value, max, warn = 0.7, danger = 0.9 }: { value: number; max: number; warn?: number; danger?: number }) {
  const pct = Math.min(value / max, 1);
  const color = pct >= danger ? "bg-red-500" : pct >= warn ? "bg-yellow-400" : "bg-emerald-400";
  return (
    <div className="w-full bg-zinc-800 rounded-full h-1.5 overflow-hidden">
      <div className={`h-full rounded-full transition-all duration-500 ${color}`} style={{ width: `${pct * 100}%` }} />
    </div>
  );
}

function fmt(n: number | null | undefined): string {
  if (n == null || isNaN(n)) return "—";
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(0)}K`;
  return String(n);
}

function modelShort(model: string | undefined): string {
  if (!model) return "—";
  const m = model.toLowerCase();
  if (m.includes("llama-3.1-8b")) return "Llama 3.1 8B";
  if (m.includes("llama-3.1-70b")) return "Llama 3.1 70B";
  if (m.includes("llama-3.3")) return "Llama 3.3";
  if (m.includes("gemini-3-flash")) return "Gemini 3 Flash";
  if (m.includes("gemini-2.5")) return "Gemini 2.5";
  if (m.includes("claude-sonnet")) return "Claude Sonnet";
  if (m.includes("claude-opus")) return "Claude Opus";
  return model.split("/").pop()?.slice(0, 20) ?? model;
}

function providerFromModel(model: string | undefined): string {
  if (!model) return "—";
  const m = model.toLowerCase();
  if (m.includes("llama") || m.includes("mixtral")) return "Groq";
  if (m.includes("gemini")) return "Gemini";
  if (m.includes("claude")) return "Anthropic";
  if (m.includes("gpt")) return "OpenAI";
  return "?";
}

export default function UsagePanel() {
  const [data, setData] = useState<UsageData>({});
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = () => fetchUsage().then(setData).catch(() => {}).finally(() => setLoading(false));
    load();
    const t = setInterval(load, 30_000);
    return () => clearInterval(t);
  }, []);

  const w5 = data.window_5h;
  const w7 = data.window_7d;
  const total = data.total;

  const tokens5h = (w5?.input_tokens ?? 0) + (w5?.output_tokens ?? 0);
  const tokens7d = (w7?.input_tokens ?? 0) + (w7?.output_tokens ?? 0);
  const pct5h = Math.round((tokens5h / LIMIT_5H) * 100);
  const warn5h = pct5h >= 70;
  const danger5h = pct5h >= 90;

  return (
    <div className="bg-zinc-900 border border-zinc-800 rounded-xl p-4 space-y-4">
      {/* Header */}
      <div className="flex items-center gap-2">
        <Zap size={14} className="text-yellow-400" />
        <h2 className="text-xs font-semibold text-zinc-200 tracking-wide uppercase">Token 使用量</h2>
        {loading && <span className="text-[10px] text-zinc-500 ml-auto">…</span>}
      </div>

      {/* Current model */}
      <div className="flex items-center gap-2 bg-zinc-800 rounded-lg px-3 py-1.5">
        <Cpu size={11} className="text-zinc-400" />
        <span className="text-[11px] text-zinc-400">模型</span>
        <span className="ml-auto text-[11px] font-mono text-zinc-200">{modelShort(data.current_model)}</span>
        <span className="text-[10px] text-zinc-600">來源 {providerFromModel(data.current_model)}</span>
      </div>

      {data.error && (
        <p className="text-xs text-red-400 flex gap-1 items-center">
          <AlertTriangle size={11} /> {data.error}
        </p>
      )}

      {/* 5h window */}
      <div className="space-y-1">
        <div className="flex justify-between items-center">
          <span className="flex items-center gap-1 text-[11px] text-zinc-400">
            <Clock size={10} /> 5 小時區間
            <span className="text-zinc-600 ml-1">({w5?.session_count ?? 0} sessions)</span>
          </span>
          <span className={`text-[11px] font-mono font-semibold ${danger5h ? "text-red-400" : warn5h ? "text-yellow-400" : "text-emerald-400"}`}>
            {fmt(tokens5h)} / {fmt(LIMIT_5H)}
          </span>
        </div>
        <ProgressBar value={tokens5h} max={LIMIT_5H} />
        {danger5h && (
          <p className="text-[10px] text-red-400 flex gap-1 items-center">
            <AlertTriangle size={10} /> 接近速率上限
          </p>
        )}
      </div>

      {/* 7d window */}
      <div className="space-y-1">
        <div className="flex justify-between items-center">
          <span className="flex items-center gap-1 text-[11px] text-zinc-400">
            <Calendar size={10} /> 7 天區間
            <span className="text-zinc-600 ml-1">({w7?.session_count ?? 0} sessions)</span>
          </span>
          <span className="text-[11px] font-mono text-zinc-300">
            {fmt(tokens7d)} / {fmt(LIMIT_7D)}
          </span>
        </div>
        <ProgressBar value={tokens7d} max={LIMIT_7D} />
      </div>

      {/* Stats grid */}
      {total && (
        <div className="grid grid-cols-2 gap-1.5 pt-2 border-t border-zinc-800">
          {[
            { label: "總 Sessions", value: total.session_count },
            { label: "累計 Tokens", value: fmt((total.input_tokens ?? 0) + (total.output_tokens ?? 0)) },
            { label: "快取讀取", value: fmt(total.cache_read) },
            { label: "預估成本", value: `$${(total.est_cost ?? 0).toFixed(4)}` },
          ].map(({ label, value }) => (
            <div key={label} className="bg-zinc-800 rounded-lg px-2.5 py-1.5">
              <p className="text-[10px] text-zinc-500">{label}</p>
              <p className="text-xs font-mono font-semibold text-zinc-200">{value}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
