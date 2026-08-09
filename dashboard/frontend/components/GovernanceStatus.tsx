"use client";

import { useCallback, useEffect, useState } from "react";
import { ShieldCheck, ShieldAlert, RefreshCw } from "lucide-react";
import { fetchGovernance } from "@/lib/api";

type Drift = { path: string; reason: string };
type Governance = {
  governance_status: "aligned" | "review_required" | "polluted" | "blocked";
  governance_version?: string;
  canonical_hash?: string;
  checked_at?: string;
  drift_count?: number;
  drift?: Drift[];
  token_cost?: number;
  model_calls?: number;
  refresh_error?: string;
};

export default function GovernanceStatus({ compact = false }: { compact?: boolean }) {
  const [data, setData] = useState<Governance | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await fetchGovernance());
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "API unavailable");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const initial = window.setTimeout(() => void refresh(), 0);
    const timer = window.setInterval(() => void refresh(), 30000);
    return () => {
      window.clearTimeout(initial);
      window.clearInterval(timer);
    };
  }, [refresh]);

  const aligned = data?.governance_status === "aligned";
  const color = aligned ? "text-emerald-300 border-emerald-800 bg-emerald-950/70" : "text-amber-300 border-amber-800 bg-amber-950/70";

  if (compact) {
    return (
      <button onClick={refresh} className={`flex items-center gap-2 rounded-lg border px-2.5 py-1.5 text-[10px] ${color}`}>
        {aligned ? <ShieldCheck size={13} /> : <ShieldAlert size={13} />}
        <span>治理 {error ? "unavailable" : (data?.governance_status ?? "checking")}</span>
        <span className="opacity-60">v{data?.governance_version ?? "?"}</span>
      </button>
    );
  }

  return (
    <div className={`absolute right-4 top-4 z-10 w-80 rounded-xl border p-3 shadow-2xl backdrop-blur ${color}`}>
      <div className="flex items-center gap-2">
        {aligned ? <ShieldCheck size={16} /> : <ShieldAlert size={16} />}
        <div>
          <p className="text-xs font-semibold">共同治理：{data?.governance_status ?? "checking"}</p>
          <p className="text-[9px] opacity-70">
            v{data?.governance_version ?? "?"} · drift {data?.drift_count ?? 0} · token {data?.token_cost ?? 0}
          </p>
        </div>
        <button onClick={refresh} className="ml-auto opacity-70 hover:opacity-100" title="重新掃描">
          <RefreshCw size={13} className={loading ? "animate-spin" : ""} />
        </button>
      </div>
      {!!data?.drift?.length && (
        <div className="mt-2 max-h-28 space-y-1 overflow-auto border-t border-current/20 pt-2">
          {data.drift.slice(0, 6).map((item) => (
            <p key={item.path} className="truncate text-[9px]" title={item.path}>
              {item.reason}: {item.path}
            </p>
          ))}
        </div>
      )}
      {data?.refresh_error && <p className="mt-2 text-[9px] text-red-300">{data.refresh_error}</p>}
      {error && <p className="mt-2 text-[9px] text-red-300">Dashboard API: {error}</p>}
      <p className="mt-2 truncate text-[8px] opacity-50" title={data?.canonical_hash}>
        {data?.canonical_hash ?? "尚無治理雜湊"}
      </p>
    </div>
  );
}
