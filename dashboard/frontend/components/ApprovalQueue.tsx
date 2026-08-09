"use client";

import { useCallback, useEffect, useState } from "react";
import { AlertTriangle, Check, RefreshCw, Square, Wrench } from "lucide-react";
import { decideApproval, fetchApprovals, fetchAuthStatus } from "@/lib/api";

interface Approval {
  task_id: string;
  source: string;
  reason: string;
  summary_for_josh: string;
  artifact_path: string;
  created_at: string;
  status: string;
}

export default function ApprovalQueue() {
  const [items, setItems] = useState<Approval[]>([]);
  const [busy, setBusy] = useState("");
  const [message, setMessage] = useState("");
  const [authenticated, setAuthenticated] = useState(false);

  const refresh = useCallback(async () => {
    const [response, auth] = await Promise.all([fetchApprovals(), fetchAuthStatus()]);
    setItems(Array.isArray(response.items) ? response.items : []);
    setAuthenticated(Boolean(auth.authenticated));
  }, []);

  useEffect(() => {
    const initial = window.setTimeout(refresh, 0);
    const timer = window.setInterval(refresh, 5000);
    return () => {
      window.clearTimeout(initial);
      window.clearInterval(timer);
    };
  }, [refresh]);

  const decide = async (
    item: Approval,
    decision: "approve" | "modify" | "stop",
  ) => {
    const labels = { approve: "核准", modify: "要求修改", stop: "停止" };
    if (!window.confirm(
      `${labels[decision]}工單 ${item.task_id}？\n\n原因：${item.reason}\n\n此操作會留下 Josh 決策紀錄。`,
    )) return;
    setBusy(item.task_id);
    setMessage("");
    try {
      await decideApproval(item.task_id, decision);
      setMessage(`已記錄：${item.task_id} → ${labels[decision]}`);
      await refresh();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "決策寫入失敗");
    } finally {
      setBusy("");
    }
  };

  return (
    <div className="flex h-full flex-col overflow-hidden bg-zinc-950">
      <header className="flex items-center border-b border-zinc-800 px-5 py-4">
        <AlertTriangle className="mr-3 text-amber-300" size={18} />
        <div>
          <h2 className="text-sm font-semibold">Josh 待核准清單</h2>
          <p className="text-[10px] text-zinc-500">只有你親自按下的決策才會寫入 resolution artifact</p>
        </div>
        <span className="ml-4 rounded bg-amber-950 px-2 py-1 text-xs text-amber-300">{items.length} 筆</span>
        <button onClick={refresh} className="ml-auto rounded border border-zinc-700 p-2" title="重新整理">
          <RefreshCw size={13} />
        </button>
      </header>

      {message && <p className="border-b border-zinc-800 px-5 py-2 text-xs text-sky-300">{message}</p>}
      {!authenticated && (
        <p className="border-b border-amber-900 bg-amber-950/30 px-5 py-3 text-xs text-amber-200">
          需登入才能決策。請使用頁首的 Owner 登入。
        </p>
      )}

      <div className="min-h-0 flex-1 overflow-auto p-5">
        <div className="space-y-3">
          {items.map((item) => (
            <article key={item.task_id} className="rounded-xl border border-amber-900 bg-amber-950/20 p-4">
              <div className="flex items-start gap-4">
                <div className="min-w-0 flex-1">
                  <p className="break-all font-mono text-[11px] text-amber-200">{item.task_id}</p>
                  <p className="mt-2 text-sm font-semibold">{item.summary_for_josh}</p>
                  <dl className="mt-3 grid gap-2 text-[10px] text-zinc-400 md:grid-cols-2">
                    <div><dt className="text-zinc-600">來源</dt><dd>{item.source}</dd></div>
                    <div><dt className="text-zinc-600">原因</dt><dd>{item.reason}</dd></div>
                    <div><dt className="text-zinc-600">建立時間</dt><dd>{item.created_at}</dd></div>
                    <div><dt className="text-zinc-600">證據</dt><dd className="break-all font-mono">{item.artifact_path}</dd></div>
                  </dl>
                </div>
                <div className="flex shrink-0 flex-col gap-2">
                  <button
                    disabled={!authenticated || busy === item.task_id}
                    onClick={() => decide(item, "approve")}
                    className="flex items-center gap-2 rounded bg-emerald-700 px-3 py-2 text-xs hover:bg-emerald-600 disabled:opacity-50"
                  >
                    <Check size={13} />核准
                  </button>
                  <button
                    disabled={!authenticated || busy === item.task_id}
                    onClick={() => decide(item, "modify")}
                    className="flex items-center gap-2 rounded bg-sky-800 px-3 py-2 text-xs hover:bg-sky-700 disabled:opacity-50"
                  >
                    <Wrench size={13} />要求修改
                  </button>
                  <button
                    disabled={!authenticated || busy === item.task_id}
                    onClick={() => decide(item, "stop")}
                    className="flex items-center gap-2 rounded bg-red-900 px-3 py-2 text-xs hover:bg-red-800 disabled:opacity-50"
                  >
                    <Square size={13} />停止
                  </button>
                </div>
              </div>
            </article>
          ))}
          {!items.length && (
            <div className="rounded-xl border border-emerald-900 bg-emerald-950/20 p-8 text-center text-sm text-emerald-300">
              目前沒有等待 Josh 的人工決策。
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
