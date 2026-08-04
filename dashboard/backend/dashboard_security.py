from __future__ import annotations

import base64
import getpass
import hashlib
import hmac
import json
import os
import re
import secrets
import subprocess
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


SESSION_COOKIE = "agentos_dashboard_session"
DEFAULT_ALLOWED_ORIGINS = (
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:3001",
    "http://127.0.0.1:3001",
    "http://localhost:3002",
    "http://127.0.0.1:3002",
)


def _utc_iso(epoch: float) -> str:
    return datetime.fromtimestamp(epoch, tz=timezone.utc).isoformat()


def _digest(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _windows_identity() -> str:
    if os.name == "nt":
        completed = subprocess.run(
            ["whoami.exe"], capture_output=True, text=True, encoding="utf-8", check=True
        )
        identity = completed.stdout.strip()
        if identity:
            return identity
    return getpass.getuser()


@dataclass(frozen=True)
class AuthContext:
    actor_id: str
    auth_method: str
    request_id: str
    csrf_token: str
    expires_at: float


class DashboardSecurity:
    def __init__(self, root: Path) -> None:
        self.root = root
        self.auth_dir = Path(os.environ.get("AGENTOS_DASHBOARD_AUTH_DIR", root / "data" / "dashboard_auth"))
        self.token_path = self.auth_dir / "owner-token.txt"
        self.decision_receipt_key_path = self.auth_dir / "decision-receipt.key"
        self.audit_path = self.auth_dir / "AUDIT_LOG.jsonl"
        self.owner_identity = os.environ.get("AGENTOS_OWNER_WINDOWS_IDENTITY", "").strip()
        self.token_ttl_seconds = int(os.environ.get("AGENTOS_DASHBOARD_TOKEN_TTL_SECONDS", "43200"))
        self.session_ttl_seconds = int(os.environ.get("AGENTOS_DASHBOARD_SESSION_TTL_SECONDS", "14400"))
        self.allowed_origins = frozenset(
            value.strip()
            for value in os.environ.get(
                "AGENTOS_DASHBOARD_ALLOWED_ORIGINS", ",".join(DEFAULT_ALLOWED_ORIGINS)
            ).split(",")
            if value.strip()
        )
        self._token_digest = ""
        self._token_expires_at = 0.0
        self._sessions: dict[str, AuthContext] = {}

    def start(self) -> None:
        self.auth_dir.mkdir(parents=True, exist_ok=True)
        if not self.owner_identity:
            self.owner_identity = _windows_identity()
        self._ensure_decision_receipt_key()
        self.rotate_owner_token()

    def _ensure_decision_receipt_key(self) -> bytes:
        if self.decision_receipt_key_path.is_file():
            return base64.b64decode(self.decision_receipt_key_path.read_text(encoding="utf-8").strip())
        key = secrets.token_bytes(32)
        temporary = self.decision_receipt_key_path.with_suffix(f".{uuid.uuid4().hex}.tmp")
        temporary.write_text(base64.b64encode(key).decode("ascii") + "\n", encoding="utf-8")
        self._restrict_file_to_owner(temporary)
        os.replace(temporary, self.decision_receipt_key_path)
        self._restrict_file_to_owner(self.decision_receipt_key_path)
        return key

    def rotate_owner_token(self) -> str:
        token = secrets.token_urlsafe(32)
        expires_at = time.time() + self.token_ttl_seconds
        temporary = self.token_path.with_suffix(f".{uuid.uuid4().hex}.tmp")
        temporary.write_text(f"{token}\nexpires_at={_utc_iso(expires_at)}\n", encoding="utf-8")
        self._restrict_file_to_owner(temporary)
        os.replace(temporary, self.token_path)
        self._restrict_file_to_owner(self.token_path)
        self._token_digest = _digest(token)
        self._token_expires_at = expires_at
        return token

    def _restrict_file_to_owner(self, path: Path) -> None:
        if os.name != "nt":
            os.chmod(path, 0o600)
            return
        completed = subprocess.run(
            [
                "icacls.exe",
                str(path),
                "/inheritance:r",
                "/grant:r",
                f"{self.owner_identity}:(F)",
            ],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
        if completed.returncode != 0:
            path.unlink(missing_ok=True)
            raise RuntimeError(
                "dashboard owner token ACL failed: "
                + (completed.stderr or completed.stdout or "icacls failed").strip()
            )

    def login(self, supplied_token: str) -> tuple[str, AuthContext]:
        now = time.time()
        if now >= self._token_expires_at:
            raise PermissionError("owner token expired")
        if not supplied_token or not hmac.compare_digest(_digest(supplied_token.strip()), self._token_digest):
            raise PermissionError("invalid owner token")
        session_id = secrets.token_urlsafe(32)
        csrf_token = secrets.token_urlsafe(32)
        context = AuthContext(
            actor_id=self.owner_identity,
            auth_method="local_owner_token",
            request_id="",
            csrf_token=csrf_token,
            expires_at=now + self.session_ttl_seconds,
        )
        self._sessions[_digest(session_id)] = context
        self.rotate_owner_token()
        return session_id, context

    def authenticate(self, session_id: str, csrf_token: str, request_id: str | None) -> AuthContext:
        now = time.time()
        self._sessions = {key: value for key, value in self._sessions.items() if value.expires_at > now}
        stored = self._sessions.get(_digest(session_id)) if session_id else None
        if not stored:
            raise PermissionError("invalid or expired session")
        if stored.actor_id != self.owner_identity:
            raise PermissionError("session actor is not the configured owner")
        if not csrf_token or not hmac.compare_digest(csrf_token, stored.csrf_token):
            raise PermissionError("invalid csrf token")
        safe_request_id = request_id if request_id and len(request_id) <= 128 else str(uuid.uuid4())
        return AuthContext(
            actor_id=stored.actor_id,
            auth_method=stored.auth_method,
            request_id=safe_request_id,
            csrf_token=stored.csrf_token,
            expires_at=stored.expires_at,
        )

    def logout(self, session_id: str) -> None:
        if session_id:
            self._sessions.pop(_digest(session_id), None)

    def session_status(self, session_id: str) -> dict:
        stored = self._sessions.get(_digest(session_id)) if session_id else None
        if not stored or stored.expires_at <= time.time() or stored.actor_id != self.owner_identity:
            return {"authenticated": False}
        return {
            "authenticated": True,
            "actor_id": stored.actor_id,
            "auth_method": stored.auth_method,
            "expires_at": _utc_iso(stored.expires_at),
            "csrf_token": stored.csrf_token,
        }

    @staticmethod
    def _decision_receipt_canonical(receipt: dict) -> str:
        bool_text = lambda value: "true" if bool(value) else "false"
        fields = (
            f"schema_version={receipt.get('schema_version', '')}",
            f"receipt_type={receipt.get('receipt_type', '')}",
            f"task_id={receipt.get('task_id', '')}",
            f"decision={receipt.get('decision', '')}",
            f"actor_id={receipt.get('actor_id', '')}",
            f"authentication_method={receipt.get('authentication_method', '')}",
            f"request_id={receipt.get('request_id', '')}",
            f"issued_at={receipt.get('issued_at', '')}",
            f"expires_at={receipt.get('expires_at', '')}",
            f"session_validated={bool_text(receipt.get('session_validated'))}",
            f"csrf_validated={bool_text(receipt.get('csrf_validated'))}",
            f"origin_validated={bool_text(receipt.get('origin_validated'))}",
            f"local_client_validated={bool_text(receipt.get('local_client_validated'))}",
            f"telegram_identity={receipt.get('telegram_identity', '')}",
            f"confirmation_code_consumed={bool_text(receipt.get('confirmation_code_consumed'))}",
        )
        return "\n".join(fields) + "\n"

    def issue_escalation_decision_receipt(
        self,
        context: AuthContext,
        task_id: str,
        decision: str,
        escalation_dir: Path,
    ) -> Path:
        """Issue a short-lived receipt only after middleware authenticated the owner.

        The receipt is bound to task, decision, actor and request ID. PowerShell
        decision and queue consumers independently validate its HMAC and path.
        """
        now = time.time()
        if context.expires_at <= now:
            raise PermissionError("owner session expired before receipt issuance")
        safe_id = re.sub(r"[^A-Za-z0-9_.-]+", "-", task_id).strip("-")
        if not safe_id or escalation_dir.name != safe_id:
            raise ValueError("escalation receipt task boundary mismatch")
        if (
            escalation_dir.is_symlink()
            or (hasattr(os.path, "isjunction") and os.path.isjunction(escalation_dir))
            or not escalation_dir.is_dir()
        ):
            raise ValueError("escalation receipt directory invalid")
        receipts_dir = escalation_dir / "receipts"
        receipts_dir.mkdir(parents=False, exist_ok=True)
        if receipts_dir.is_symlink() or (
            hasattr(os.path, "isjunction") and os.path.isjunction(receipts_dir)
        ):
            raise ValueError("escalation receipt directory link rejected")
        issued_at = _utc_iso(now)
        expires_at = _utc_iso(min(context.expires_at, now + 120))
        receipt = {
            "schema_version": "1",
            "receipt_type": "dashboard_owner_session",
            "task_id": task_id,
            "decision": decision,
            "actor_id": context.actor_id,
            "authentication_method": context.auth_method,
            "request_id": context.request_id,
            "issued_at": issued_at,
            "expires_at": expires_at,
            "session_validated": True,
            "csrf_validated": True,
            "origin_validated": True,
            "local_client_validated": True,
            "telegram_identity": "",
            "confirmation_code_consumed": False,
            "source_api": f"/api/approvals/{task_id}/decision",
        }
        key = self._ensure_decision_receipt_key()
        receipt["signature"] = hmac.new(
            key,
            self._decision_receipt_canonical(receipt).encode("utf-8"),
            hashlib.sha256,
        ).hexdigest().upper()
        stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S-%f")[:-3]
        path = receipts_dir / f"DASHBOARD-{stamp}-{uuid.uuid4().hex[:8]}.json"
        temporary = path.with_suffix(f".{uuid.uuid4().hex}.tmp")
        temporary.write_text(
            json.dumps(receipt, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        self._restrict_file_to_owner(temporary)
        os.replace(temporary, path)
        self._restrict_file_to_owner(path)
        return path

    def verify_escalation_decision_record(self, record: dict, escalation_dir: Path) -> bool:
        """Validate a stored DECISION without requiring its short-lived receipt to remain live."""
        receipt_meta = record.get("receipt") if isinstance(record, dict) else None
        if not isinstance(receipt_meta, dict) or not receipt_meta.get("path"):
            return False
        try:
            receipt_path = Path(receipt_meta["path"])
            receipt_root = (escalation_dir / "receipts").resolve(strict=True)
            resolved = receipt_path.resolve(strict=True)
            resolved.relative_to(receipt_root)
            if (
                receipt_path.is_symlink()
                or receipt_root.is_symlink()
                or (hasattr(os.path, "isjunction") and os.path.isjunction(receipt_path))
                or (hasattr(os.path, "isjunction") and os.path.isjunction(receipt_root))
            ):
                return False
            receipt = json.loads(resolved.read_text(encoding="utf-8"))
            if file_sha256(resolved) != receipt_meta.get("sha256"):
                return False
            for receipt_key, decision_key in (
                ("task_id", "task_id"),
                ("decision", "decision"),
                ("actor_id", "decided_by"),
                ("authentication_method", "authentication_method"),
                ("request_id", "request_id"),
            ):
                if receipt.get(receipt_key) != record.get(decision_key):
                    return False
            receipt_type = receipt.get("receipt_type")
            if receipt_type == "dashboard_owner_session":
                if receipt.get("authentication_method") != "local_owner_token" or not all(
                    receipt.get(key) is True
                    for key in (
                        "session_validated",
                        "csrf_validated",
                        "origin_validated",
                        "local_client_validated",
                    )
                ):
                    return False
            elif receipt_type == "telegram_one_time_confirmation":
                if (
                    receipt.get("authentication_method") != "telegram_one_time_confirmation"
                    or not os.environ.get("AGENTOS_OWNER_TELEGRAM_ID")
                    or receipt.get("telegram_identity") != os.environ.get("AGENTOS_OWNER_TELEGRAM_ID")
                    or receipt.get("confirmation_code_consumed") is not True
                ):
                    return False
            else:
                return False
            issued = datetime.fromisoformat(str(receipt["issued_at"]).replace("Z", "+00:00"))
            expires = datetime.fromisoformat(str(receipt["expires_at"]).replace("Z", "+00:00"))
            decided = datetime.fromisoformat(str(record["decided_at"]).replace("Z", "+00:00"))
            if not issued <= decided <= expires:
                return False
            if not self.decision_receipt_key_path.is_file():
                return False
            key = base64.b64decode(
                self.decision_receipt_key_path.read_text(encoding="utf-8").strip()
            )
            expected = hmac.new(
                key,
                self._decision_receipt_canonical(receipt).encode("utf-8"),
                hashlib.sha256,
            ).hexdigest().upper()
            return bool(receipt.get("signature")) and hmac.compare_digest(
                expected, str(receipt["signature"]).upper()
            )
        except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError):
            return False

    def write_audit(
        self,
        context: AuthContext,
        action: str,
        artifact_path: Path | None,
        before_hash: str | None,
        after_hash: str | None,
        before_state: str | None = None,
        after_state: str | None = None,
    ) -> None:
        event = {
            "timestamp": _utc_iso(time.time()),
            "actor_id": context.actor_id,
            "auth_method": context.auth_method,
            "request_id": context.request_id,
            "action": action,
            "artifact_path": str(artifact_path) if artifact_path else None,
            "before_state": before_state,
            "after_state": after_state,
            "before_hash": before_hash,
            "after_hash": after_hash,
            "artifact_hash": after_hash,
        }
        self.audit_path.parent.mkdir(parents=True, exist_ok=True)
        with self.audit_path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(event, ensure_ascii=False, separators=(",", ":")) + "\n")


def file_sha256(path: Path | None) -> str | None:
    if not path or not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()
