# Source Dockerfile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a multi-stage Dockerfile that builds VerneMQ from this source tree and preserves the official image's core runtime surface without downloading EULA-restricted release packages.

**Architecture:** The Dockerfile uses a builder stage with Erlang/OTP and native build dependencies to run `make rel`. The runtime stage copies only `_build/default/rel/vernemq` into a Debian slim image, creates the `vernemq` UID/GID 10000 user, exposes the official ports, declares the official volumes, and starts the release in the foreground.

**Tech Stack:** Docker multi-stage build, Debian bookworm slim, Erlang/OTP Docker image, GNU make, rebar3 release, VerneMQ release runner.

---

## File Structure

- Create: `Dockerfile`
  - Builds VerneMQ from source and defines the runtime image.
- Already created: `docs/superpowers/specs/2026-05-07-source-dockerfile-design.md`
  - Design constraints and explicit non-goals.
- Create: `docs/superpowers/plans/2026-05-07-source-dockerfile.md`
  - This implementation plan.

## Task 1: Add Multi-Stage Dockerfile

**Files:**
- Create: `Dockerfile`

- [ ] **Step 1: Write the Dockerfile**

Create `Dockerfile` with this content:

```dockerfile
# syntax=docker/dockerfile:1

ARG OTP_VERSION=26

FROM erlang:${OTP_VERSION} AS builder

WORKDIR /build/vernemq

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
        libsnappy-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN make rel

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        procps \
        openssl \
        iproute2 \
        curl \
        jq \
        libsnappy-dev \
        net-tools \
    && rm -rf /var/lib/apt/lists/* \
    && addgroup --gid 10000 vernemq \
    && adduser --uid 10000 --system --ingroup vernemq --home /vernemq --disabled-password vernemq

WORKDIR /vernemq

ENV DOCKER_VERNEMQ_LOG__CONSOLE=console \
    PATH="/vernemq/bin:${PATH}"

COPY --from=builder --chown=10000:10000 /build/vernemq/_build/default/rel/vernemq/ /vernemq/

RUN ln -s /vernemq/etc /etc/vernemq \
    && ln -s /vernemq/data /var/lib/vernemq \
    && ln -s /vernemq/log /var/log/vernemq

EXPOSE 1883 8883 8080 44053 4369 8888 \
    9100 9101 9102 9103 9104 9105 9106 9107 9108 9109

VOLUME ["/vernemq/log", "/vernemq/data", "/vernemq/etc"]

HEALTHCHECK CMD vernemq ping | grep -q pong

USER vernemq

CMD ["vernemq", "console", "-noshell", "-noinput"]
```

- [ ] **Step 2: Inspect the Dockerfile**

Run:

```bash
sed -n '1,220p' Dockerfile
```

Expected: the file contains two `FROM` stages, no reference to `github.com/vernemq/vernemq/releases/download`, and keeps `USER vernemq`, `HEALTHCHECK`, `VOLUME`, and the official port list.

- [ ] **Step 3: Commit the Dockerfile**

Run:

```bash
git add Dockerfile
git commit -m "添加源码构建 Dockerfile"
```

Expected: a commit is created containing only `Dockerfile`.

## Task 2: Verify Dockerfile

**Files:**
- Verify: `Dockerfile`

- [ ] **Step 1: Check Dockerfile for EULA package download references**

Run:

```bash
rg -n "releases/download|bookworm\\.\\$ARCH|\\.tar\\.gz|curl -L https://github.com/vernemq/vernemq" Dockerfile
```

Expected: command exits with code `1` and prints no matches.

- [ ] **Step 2: Build the image when Docker is available**

Run:

```bash
docker build -t vernemq:source .
```

Expected: Docker completes the multi-stage build and creates image `vernemq:source`.

- [ ] **Step 3: Smoke test the image when the build succeeds**

Run:

```bash
docker run --rm --name vernemq-source-smoke -e DOCKER_VERNEMQ_ACCEPT_EULA=yes -p 1883:1883 -d vernemq:source
sleep 20
docker exec vernemq-source-smoke vernemq ping
docker stop vernemq-source-smoke
```

Expected: `docker exec` prints `pong`, and `docker stop` stops the container cleanly.

- [ ] **Step 4: Capture repository status**

Run:

```bash
git status --short
```

Expected: only intended plan/doc changes remain, or the worktree is clean if the plan document was committed separately.

## Self-Review

- Spec coverage: Task 1 implements multi-stage source build, non-root runtime, ports, volumes, healthcheck, PATH, and foreground start command. Task 2 verifies absence of EULA release package downloads and attempts a real Docker build/smoke test.
- Placeholder scan: no prohibited placeholder patterns or vague test instructions remain.
- Type consistency: all paths and commands refer to `Dockerfile`, `docs/superpowers/specs/2026-05-07-source-dockerfile-design.md`, and `docs/superpowers/plans/2026-05-07-source-dockerfile.md` consistently.
