# Docker 镜像发布 Workflow 设计

## 背景

项目已经新增源码构建版 Dockerfile，并能构建 `vernemq:source` 镜像。现在需要在 GitHub Actions 中新增独立 workflow，在代码推送或打 Git tag 后自动构建镜像并推送到 Docker Hub 仓库 `ruishanio/vernemq`。

## 范围

本次新增独立 GitHub Actions workflow：

- 文件路径：`.github/workflows/docker-image.yml`。
- 使用仓库根目录 `Dockerfile` 构建镜像。
- 推送目标镜像：`ruishanio/vernemq`。
- 支持手动触发：`workflow_dispatch`。
- 支持代码推送触发：
  - `main`
  - `release-*`
- 支持 tag 推送触发：
  - `v*`
  - `*.*.*`
- 使用 GitHub Secrets 登录 Docker Hub：
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`

## Tag 策略

Git tag 推送时需要把对应 tag 发布到 Docker Hub：

- `refs/tags/v2.1.2` 发布：
  - `ruishanio/vernemq:v2.1.2`
  - `ruishanio/vernemq:2.1.2`
- `refs/tags/2.1.2` 发布：
  - `ruishanio/vernemq:2.1.2`

分支推送时：

- `main` 发布 `ruishanio/vernemq:latest`。
- 其他分支发布分支名 tag，例如 `release-2.1.2`。
- 每次构建都附带短 SHA tag，便于追踪具体提交。

## 实现方式

使用 Docker 官方 GitHub Actions：

- `docker/login-action`：登录 Docker Hub。
- `docker/metadata-action`：根据 Git ref 生成镜像 tag 和 OCI label。
- `docker/build-push-action`：构建并推送镜像。

workflow 不在 PR 中推送镜像，避免未经授权的 fork PR 获取发布凭据。该 workflow 只在 `push` 和手动触发时运行。

## 验证

实现后执行静态检查：

- 检查 workflow YAML 可解析。
- 检查 workflow 中包含 Docker Hub 仓库、登录 secrets、tag 匹配规则和 `push: true`。
- 检查仓库状态只包含预期文件。

真实推送需要在 GitHub 仓库配置 Docker Hub secrets 后，由 GitHub Actions 执行验证。
