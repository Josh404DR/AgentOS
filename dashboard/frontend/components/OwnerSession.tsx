"use client";

import { useEffect, useState } from "react";
import { fetchAuthStatus, loginOwner, logoutOwner } from "@/lib/api";

type AuthStatus = {
  authenticated: boolean;
  actor_id?: string;
  expires_at?: string;
};

export default function OwnerSession() {
  const [status, setStatus] = useState<AuthStatus>({ authenticated: false });
  const [token, setToken] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    void fetchAuthStatus().then(setStatus).catch(() => setStatus({ authenticated: false }));
  }, []);

  async function login() {
    setBusy(true);
    setError("");
    try {
      const next = await loginOwner(token.trim());
      setStatus(next);
      setToken("");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "登入失敗");
    } finally {
      setBusy(false);
    }
  }

  async function logout() {
    setBusy(true);
    try {
      await logoutOwner();
      setStatus({ authenticated: false });
    } finally {
      setBusy(false);
    }
  }

  if (status.authenticated) {
    return (
      <div className="flex items-center gap-2 text-[10px] text-zinc-400">
        <span title={status.expires_at}>Owner：{status.actor_id}</span>
        <button disabled={busy} onClick={logout} className="border border-zinc-700 px-2 py-1 hover:bg-zinc-800">
          登出
        </button>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-2">
      <label className="sr-only" htmlFor="owner-token">本機 owner token</label>
      <input
        id="owner-token"
        type="password"
        autoComplete="off"
        value={token}
        onChange={(event) => setToken(event.target.value)}
        placeholder="貼入本機 owner token"
        className="w-48 border border-zinc-700 bg-zinc-900 px-2 py-1 text-[10px] text-zinc-100"
      />
      <button disabled={busy || !token.trim()} onClick={login} className="border border-cyan-800 px-2 py-1 text-[10px] text-cyan-300 disabled:opacity-40">
        Owner 登入
      </button>
      <span className="hidden max-w-72 text-[10px] text-zinc-500 lg:inline">
        token：E:\AgentOS\data\dashboard_auth\owner-token.txt；過期請重啟 backend
      </span>
      {error && <span className="max-w-72 text-[10px] text-red-400" title={error}>{error}</span>}
    </div>
  );
}
