from __future__ import annotations

import asyncio
import os
import socket
import subprocess
import sys
import time
from pathlib import Path

import httpx
import websockets


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "dashboard" / "backend"


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


async def wait_health(port: int, timeout: float = 20) -> None:
    deadline = time.monotonic() + timeout
    async with httpx.AsyncClient() as client:
        while time.monotonic() < deadline:
            try:
                response = await client.get(f"http://127.0.0.1:{port}/api/health", timeout=1)
                if response.status_code == 200:
                    return
            except httpx.HTTPError:
                pass
            await asyncio.sleep(0.2)
    raise RuntimeError("backend health endpoint did not become ready")


async def exercise(port: int) -> None:
    await wait_health(port)
    async with websockets.connect(f"ws://127.0.0.1:{port}/ws/bridge/latest"):
        main_path = BACKEND / "main.py"
        original = main_path.stat().st_mtime
        os.utime(main_path, None)
        try:
            await asyncio.sleep(1)
            await wait_health(port, timeout=3)
        finally:
            os.utime(main_path, (original, original))


def main() -> int:
    port = free_port()
    process = subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "main:app", "--host", "127.0.0.1", "--port", str(port)],
        cwd=BACKEND,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        asyncio.run(exercise(port))
    finally:
        process.terminate()
        try:
            stdout, stderr = process.communicate(timeout=12)
        except subprocess.TimeoutExpired:
            process.kill()
            stdout, stderr = process.communicate(timeout=5)
            print(stdout)
            print(stderr, file=sys.stderr)
            raise RuntimeError("backend did not shut down with an active WebSocket")
    if process.returncode not in (0, -15, 1):
        print(stdout)
        print(stderr, file=sys.stderr)
        raise RuntimeError(f"unexpected backend exit code: {process.returncode}")
    print("dashboard_lifecycle_status=PASS")
    print("reload_enabled=false")
    print("websocket_connected=true")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
