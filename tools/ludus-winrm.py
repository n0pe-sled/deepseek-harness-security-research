#!/opt/windows-remote/bin/python
"""Execute PowerShell unattended through NTLM using Ludus VM credentials."""

import os
import re
import sys

import winrm


if len(sys.argv) < 3 or not re.fullmatch(r"[A-Za-z0-9._-]+", sys.argv[1]):
    print("usage: ludus-winrm HOST POWERSHELL", file=sys.stderr)
    raise SystemExit(2)

host = sys.argv[1]
command = " ".join(sys.argv[2:])
domain = os.environ.get("LUDUS_WINDOWS_DOMAIN", "LUDUS")
preferred_user = os.environ.get("LUDUS_WINDOWS_USER", "")
preferred_password = os.environ.get("LUDUS_WINDOWS_PASSWORD", "")

candidates = []
if preferred_user and preferred_password:
    candidates.append(("configured", preferred_user, preferred_password))
candidates.extend(
    [
        (
            "local-administrator",
            os.environ.get("LUDUS_WINDOWS_LOCAL_USER", "localuser"),
            os.environ.get("LUDUS_WINDOWS_LOCAL_PASSWORD", "password"),
        ),
        (
            "domain-administrator",
            domain + "\\" + os.environ.get("LUDUS_WINDOWS_DOMAIN_ADMIN", "domainadmin"),
            os.environ.get("LUDUS_WINDOWS_DOMAIN_ADMIN_PASSWORD", "password"),
        ),
        (
            "domain-user",
            domain + "\\" + os.environ.get("LUDUS_WINDOWS_DOMAIN_USER", "domainuser"),
            os.environ.get("LUDUS_WINDOWS_DOMAIN_USER_PASSWORD", "password"),
        ),
    ]
)

port = int(os.environ.get("LUDUS_WINRM_PORT", "5985"))
endpoint = f"http://{host}:{port}/wsman"
last_error = None
for label, username, password in candidates:
    try:
        session = winrm.Session(
            endpoint,
            auth=(username, password),
            transport="ntlm",
            read_timeout_sec=120,
            operation_timeout_sec=90,
        )
        result = session.run_ps(command)
        sys.stdout.buffer.write(result.std_out)
        sys.stderr.buffer.write(result.std_err)
        print(f"\nwinrm_auth={label}", file=sys.stderr)
        raise SystemExit(result.status_code)
    except SystemExit:
        raise
    except Exception as error:  # move to the next configured identity
        last_error = error

print(
    "ludus-winrm: no configured Windows identity authenticated"
    + (f" ({type(last_error).__name__})" if last_error else ""),
    file=sys.stderr,
)
raise SystemExit(1)
