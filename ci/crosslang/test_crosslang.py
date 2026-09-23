"""Cross-language session tests: jennah-sdk-go and jennah-sdk-py sharing one file.

The conformance suite proves each SDK satisfies client-credentials on its own.
These prove the property that contract exists for: two different languages'
clients, in two processes, sharing one stored session without stranding each
other. Run by run.sh against the Go tree and Python distribution that verify
just tested, so both halves are the code being released.

Env: GOHELPER, the built ci/crosslang/gohelper binary.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import threading
import time
from concurrent import futures

import grpc
import pytest

import jennah
from jennah import credentials
from jennah.agent.v1 import agent_pb2, agent_pb2_grpc
from jennah.auth.v1 import auth_pb2, auth_pb2_grpc

GOHELPER = os.environ.get("GOHELPER", "")


def _bearer(context) -> str:
    for k, v in context.invocation_metadata():
        if k == "authorization":
            return v.removeprefix("Bearer ")
    return ""


class Platform(agent_pb2_grpc.AgentServiceServicer, auth_pb2_grpc.AuthServiceServicer):
    """Accepts one access token, and rotates on refresh exactly as the platform
    does: the refresh token presented is dead from that moment."""

    def __init__(self):
        self.mu = threading.Lock()
        self.accept = "at_current"
        self.refresh_accept = "rt_valid"
        self.presented: list[str] = []
        self.refreshes = 0

    def ListAgents(self, request, context):
        with self.mu:
            got = _bearer(context)
            self.presented.append(got)
            ok = got == self.accept
        if not ok:
            context.abort(grpc.StatusCode.UNAUTHENTICATED, "the access token is invalid or has expired")
        return agent_pb2.ListAgentsResponse()

    def RefreshToken(self, request, context):
        with self.mu:
            if request.refresh_token != self.refresh_accept:
                context.abort(grpc.StatusCode.UNAUTHENTICATED, "the refresh token is invalid or has expired")
            self.refreshes += 1
            self.accept = f"at_renewed_{self.refreshes}"
            self.refresh_accept = f"rt_rotated_{self.refreshes}"
            return auth_pb2.RefreshTokenResponse(
                access_token=self.accept, refresh_token=self.refresh_accept, expires_in=3600
            )


@pytest.fixture
def machine(tmp_path, monkeypatch):
    # One empty machine shared by both processes: the Go helper inherits this env.
    monkeypatch.setenv("XDG_CONFIG_HOME", str(tmp_path))
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.delenv("JENNAH_API_KEY", raising=False)
    assert GOHELPER and os.access(GOHELPER, os.X_OK), "GOHELPER must name the built Go helper"
    return tmp_path


@pytest.fixture
def platform():
    p = Platform()
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=8))
    agent_pb2_grpc.add_AgentServiceServicer_to_server(p, server)
    auth_pb2_grpc.add_AuthServiceServicer_to_server(p, server)
    p.endpoint = f"127.0.0.1:{server.add_insecure_port('127.0.0.1:0')}"
    server.start()
    yield p
    server.stop(None)


def expired_session():
    # Written in the canonical format, as a login would have left it.
    path = credentials.session_path()
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    with open(path, "w") as f:
        json.dump({"endpoint": "https://jennah.alphaus.cloud", "access_token": "at_expired",
                   "refresh_token": "rt_valid", "token_type": "Bearer",
                   "expires_at": int(time.time()) - 60}, f, indent=2)
    os.chmod(path, 0o600)


def go(*args, timeout=60) -> str:
    r = subprocess.run([GOHELPER, *args], capture_output=True, text=True, timeout=timeout)
    assert r.returncode == 0, f"gohelper {' '.join(args)}: {r.stderr.strip()}"
    return r.stdout.strip()


def python_call(endpoint: str) -> None:
    with jennah.Client(endpoint=endpoint, insecure=True) as c:
        c.agents.ListAgents(agent_pb2.ListAgentsRequest(), timeout=20)


def test_go_renewal_keeps_python_authenticated(machine, platform):
    """5.3: Go renews and rotates; Python, reading the shared file, authenticates
    with the renewed session and never presents the dead one."""
    expired_session()
    assert go("call", platform.endpoint) == "ok"
    assert platform.refreshes == 1

    python_call(platform.endpoint)
    assert platform.refreshes == 1, "Python renewed again instead of adopting Go's renewal"
    assert platform.presented[-1] == "at_renewed_1"
    assert credentials.load_session().refresh_token == "rt_rotated_1"


def test_python_renewal_keeps_go_authenticated(machine, platform):
    """5.2 (the Go half; jnh is covered by the live check): Python renews and
    rotates; Go authenticates with the renewed session."""
    expired_session()
    python_call(platform.endpoint)
    assert platform.refreshes == 1

    assert go("call", platform.endpoint) == "ok"
    assert platform.refreshes == 1, "Go renewed again instead of adopting Python's renewal"
    assert platform.presented[-1] == "at_renewed_1"


def test_renewals_alternate_between_languages(machine, platform):
    """Each language renews in turn, each time with the refresh token the other
    wrote. A client that kept a rotation private would break the chain at the
    next step, because the token on disk would already be dead."""
    expired_session()
    for round_ in range(1, 5):
        if round_ > 1:
            # The stored access token expires, as time would make it.
            with platform.mu:
                platform.accept = "not-yet-issued"
        if round_ % 2:
            assert go("call", platform.endpoint) == "ok"
        else:
            python_call(platform.endpoint)
        assert platform.refreshes == round_
        assert credentials.load_session().refresh_token == f"rt_rotated_{round_}"


def _py_token(n: int) -> str:
    return f"py_{n}_" + "x" * (n % 37)


_SHAPE = re.compile(r"^(go|py)_(\d+)_(x*)$")


def _whole(tok: str) -> bool:
    m = _SHAPE.match(tok)
    return bool(m) and len(m.group(3)) == int(m.group(2)) % 37


def test_concurrent_session_file_io_across_languages(machine):
    """5.4: both languages rewrite the file while both read it. No reader in
    either language ever sees a torn or interleaved session."""
    credentials.save_session(credentials.Session(access_token=_py_token(0), refresh_token="rt"))
    py_partial, py_reads = 0, 0
    stop = threading.Event()

    def py_reader():
        nonlocal py_partial, py_reads
        while not stop.is_set():
            try:
                s = credentials.load_session()
                bad = not _whole(s.access_token)
            except Exception:  # noqa: BLE001
                bad = True
            py_reads += 1
            py_partial += bad

    def py_writer():
        for n in range(300):
            credentials.save_session(credentials.Session(
                endpoint="https://jennah.alphaus.cloud", access_token=_py_token(n),
                refresh_token="rt", token_type="Bearer"))

    reader = threading.Thread(target=py_reader)
    reader.start()
    go_reader = subprocess.Popen([GOHELPER, "read", "3"], stdout=subprocess.PIPE, text=True)
    go_writer = subprocess.Popen([GOHELPER, "write", "300"], stdout=subprocess.PIPE, text=True)
    writer = threading.Thread(target=py_writer)
    writer.start()
    writer.join()
    assert go_writer.wait(timeout=60) == 0
    go_out = go_reader.communicate(timeout=60)[0].split()
    stop.set()
    reader.join()

    go_reads, go_partial = int(go_out[0]), int(go_out[1])
    assert go_reads > 0 and py_reads > 0
    assert go_partial == 0, f"Go read {go_partial} torn sessions in {go_reads} reads"
    assert py_partial == 0, f"Python read {py_partial} torn sessions in {py_reads} reads"
    if sys.platform != "win32":
        path = credentials.session_path()
        assert os.stat(path).st_mode & 0o777 == 0o600
        assert os.listdir(os.path.dirname(path)) == ["credentials"], "a temporary file was left behind"
