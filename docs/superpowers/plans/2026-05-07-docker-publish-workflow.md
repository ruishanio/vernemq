# Docker Publish Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independent GitHub Actions workflow that builds this repository's Docker image and pushes it to `ruishanio/vernemq`, including Docker tags that mirror Git tags.

**Architecture:** A dedicated workflow under `.github/workflows/docker-image.yml` handles Docker publishing separately from PR checks. It uses Docker Hub credentials from GitHub Secrets, Docker metadata generation for tags and labels, and Docker Buildx for building and pushing the root `Dockerfile`.

**Tech Stack:** GitHub Actions, Docker Hub, `docker/login-action`, `docker/metadata-action`, `docker/build-push-action`, repository root Dockerfile.

---

## File Structure

- Create: `.github/workflows/docker-image.yml`
  - Builds and pushes `ruishanio/vernemq`.
- Already created: `docs/superpowers/specs/2026-05-07-docker-publish-workflow-design.md`
  - Records trigger, secret, and tag policy.
- Create: `docs/superpowers/plans/2026-05-07-docker-publish-workflow.md`
  - This implementation plan.

## Task 1: Add Docker Publish Workflow

**Files:**
- Create: `.github/workflows/docker-image.yml`

- [ ] **Step 1: Create workflow file**

Create `.github/workflows/docker-image.yml` with:

```yaml
---
name: Build and publish Docker image

on:
  push:
    branches:
      - main
      - "release-*"
    tags:
      - "v*"
      - "*.*.*"
  workflow_dispatch:

env:
  DOCKER_IMAGE: ruishanio/vernemq

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  docker:
    name: Build and push Docker image
    runs-on: ubuntu-24.04
    permissions:
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v5
        with:
          fetch-depth: 0

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.DOCKER_IMAGE }}
          tags: |
            type=ref,event=branch
            type=ref,event=tag
            type=match,pattern=v(.*),group=1
            type=raw,value=latest,enable={{is_default_branch}}
            type=sha,format=short,prefix=sha-

      - name: Build and push Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

- [ ] **Step 2: Verify workflow can be parsed**

Run:

```bash
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/docker-image.yml"); puts "yaml ok"'
```

Expected: prints `yaml ok`.

- [ ] **Step 3: Verify required workflow fields**

Run:

```bash
rg -n "ruishanio/vernemq|DOCKERHUB_USERNAME|DOCKERHUB_TOKEN|docker/login-action@v3|docker/metadata-action@v5|docker/build-push-action@v6|type=ref,event=tag|type=match,pattern=v\\(\\.\\*\\),group=1|push: true" .github/workflows/docker-image.yml
```

Expected: every required token is found.

- [ ] **Step 4: Verify branch and tag triggers**

Run:

```bash
rg -n 'main|release-\\*|"v\\*"|"\\*\\.\\*\\.\\*"|workflow_dispatch' .github/workflows/docker-image.yml
```

Expected: finds all push branches, tag patterns, and manual trigger.

## Task 2: Commit Workflow

**Files:**
- Create: `.github/workflows/docker-image.yml`

- [ ] **Step 1: Check repository status**

Run:

```bash
git status --short
```

Expected: only `.github/workflows/docker-image.yml` and this plan file are uncommitted.

- [ ] **Step 2: Commit workflow and plan**

Run:

```bash
git add .github/workflows/docker-image.yml docs/superpowers/plans/2026-05-07-docker-publish-workflow.md
git commit -m "添加 Docker 镜像发布 workflow"
```

Expected: commit succeeds.

## Self-Review

- Spec coverage: Task 1 implements independent workflow, Docker Hub repository, branch/tag/manual triggers, GitHub Secrets, Docker tag policy, and push behavior. Task 2 commits the implementation.
- Placeholder scan: no prohibited placeholder patterns or vague validation steps remain.
- Consistency: workflow path, Docker image name, secret names, and action versions match the design.
