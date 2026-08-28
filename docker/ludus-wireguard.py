#!/usr/bin/env python3
"""Bring up the current Ludus user tunnel without persisting its private key."""

import json
import os
import pathlib
import shutil
import ssl
import subprocess
import sys
import urllib.parse
import urllib.request


def fail(message: str) -> None:
    print(f"Ludus range connection failed: {message}", file=sys.stderr)
    raise SystemExit(2)


mode = os.environ.get("LUDUS_RANGE_CONNECT", "auto")
if mode == "host":
    print("Ludus range connection: using Docker Desktop/host VPN routing")
    raise SystemExit(0)
if mode not in {"auto", "wireguard"}:
    fail("LUDUS_RANGE_CONNECT must be auto, wireguard, host, or api-only")

if subprocess.run(
    ["wg", "show", "ludus"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
).returncode == 0:
    print("Ludus range connection: reusing the active WireGuard interface")
    raise SystemExit(0)

target = pathlib.Path("/run/ludus.conf")
source = os.environ.get("LUDUS_WIREGUARD_CONFIG", "")
if source:
    source_path = pathlib.Path(source)
    if not source_path.is_file():
        fail("LUDUS_WIREGUARD_CONFIG does not name a mounted file")
    shutil.copyfile(source_path, target)
else:
    base = os.environ.get("LUDUS_URL", "").rstrip("/")
    key = os.environ.get("LUDUS_API_KEY", "")
    parsed = urllib.parse.urlsplit(base)
    if parsed.scheme != "https" or not parsed.netloc or parsed.username or parsed.query or parsed.fragment:
        fail("LUDUS_URL must be an HTTPS server origin")
    if not key or "." not in key:
        fail("LUDUS_API_KEY is missing or malformed")
    api = base if parsed.path.rstrip("/") == "/api/v2" else base + "/api/v2"
    request = urllib.request.Request(
        api + "/user/wireguard",
        headers={"X-API-KEY": key, "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(
            request, timeout=15, context=ssl._create_unverified_context()
        ) as response:
            body = response.read()
    except Exception as error:
        fail(f"could not retrieve the user WireGuard configuration: {error}")

    try:
        document = json.loads(body)
    except Exception:
        fail("WireGuard endpoint did not return JSON")

    pending = [document]
    config = None
    while pending:
        value = pending.pop()
        if isinstance(value, dict):
            pending.extend(value.values())
        elif isinstance(value, list):
            pending.extend(value)
        elif isinstance(value, str) and "[Interface]" in value and "[Peer]" in value:
            config = value
            break
    if config is None:
        fail("WireGuard endpoint response did not contain a client configuration")
    target.write_text(config, encoding="utf-8")

os.chmod(target, 0o600)
try:
    subprocess.run(["wg-quick", "up", str(target)], check=True)
except Exception as error:
    fail(f"wg-quick could not establish the tunnel: {error}")
print("Ludus range connection: WireGuard is active; configuration remains ephemeral")
