"use client";

import { FormEvent, useState } from "react";
import { Bot, FileText, Send } from "lucide-react";
import { askStatus } from "@/lib/api";

interface Citation { path: string; timestamp?: string | null }
interface Reply { answer: string; citations: Citation[]; models_invoked: boolean }

export default function StatusAssistant() {
  const [question, setQuestion] = useState("");
  const [reply, setReply] = useState<Reply | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!question.trim()) return;
    setLoading(true);
    setError(null);
    try { setReply(await askStatus(question)); }
    catch (reason) { setError(reason instanceof Error ? reason.message : "status query failed"); }
    finally { setLoading(false); }
  }

  return (
    <section className="flex h-full min-h-0 flex-col bg-zinc-950">
      <header className="flex items-center gap-2 border-b border-zinc-800 px-4 py-3">
        <Bot size={15} className="text-cyan-400" />
        <h2 className="text-xs font-semibold text-zinc-200">Status assistant</h2>
        <span className="ml-auto text-[9px] text-zinc-600">local evidence · no model</span>
      </header>
      <div className="flex-1 space-y-3 overflow-y-auto p-4">
        {!reply && !error && <p className="text-xs text-zinc-500">Ask about a dispatch ID or a registered runtime.</p>}
        {error && <p className="border border-red-900 bg-red-950 p-3 text-xs text-red-200">{error}</p>}
        {reply && (
          <div className="space-y-3">
            <pre className="whitespace-pre-wrap border border-zinc-800 bg-zinc-900 p-3 text-xs leading-relaxed text-zinc-200">{reply.answer}</pre>
            <div className="space-y-1">
              {reply.citations.map((citation, index) => (
                <p key={`${citation.path}-${index}`} className="flex items-start gap-2 break-all font-mono text-[9px] text-zinc-500">
                  <FileText size={10} className="mt-0.5 shrink-0" />{citation.path}{citation.timestamp ? ` · ${citation.timestamp}` : ""}
                </p>
              ))}
            </div>
          </div>
        )}
      </div>
      <form onSubmit={submit} className="flex gap-2 border-t border-zinc-800 p-3">
        <input value={question} onChange={(event) => setQuestion(event.target.value)} placeholder="dispatch ID or runtime ID" className="min-w-0 flex-1 border border-zinc-700 bg-zinc-900 px-3 py-2 text-xs text-zinc-100 outline-none focus:border-cyan-600" />
        <button type="submit" disabled={loading || !question.trim()} title="Query local status" className="h-8 w-8 border border-cyan-700 bg-cyan-900 text-cyan-100 disabled:opacity-40"><Send size={13} className="mx-auto" /></button>
      </form>
    </section>
  );
}
