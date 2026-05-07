# VerneMQ 源码构建 Dockerfile 设计

## 背景

官方 `vernemq/docker-vernemq` 镜像的 Dockerfile 会下载 GitHub release 中的预编译 VerneMQ tarball。该发行包受 EULA 限制，因此本项目需要提供一个从当前源码树直接构建 VerneMQ release 的 Dockerfile，同时保留官方镜像的基础运行表面。

## 范围

本次只实现源码构建版运行镜像，保留以下行为：

- 多阶段 Docker 构建。
- 从当前仓库源码执行 `make rel` 生成 VerneMQ release。
- 最终镜像使用非 root 用户 `vernemq`，UID/GID 为 `10000`。
- 工作目录为 `/vernemq`，并把 `/vernemq/bin` 加入 `PATH`。
- 保留官方镜像端口：`1883`、`8883`、`8080`、`44053`、`4369`、`8888`、`9100-9109`。
- 保留官方镜像 volume：`/vernemq/log`、`/vernemq/data`、`/vernemq/etc`。
- 保留健康检查：`vernemq ping | grep -q pong`。
- 使用 release 自带命令以前台方式启动 VerneMQ，便于 Docker 管理进程生命周期。

本次不实现官方 Docker 启动脚本中的功能：

- `DOCKER_VERNEMQ_*` 环境变量到 `vernemq.conf` 的动态转换。
- Kubernetes、Swarm、Compose 自动发现和自动入集群逻辑。
- 启动时创建用户、API key 或动态改写 `vm.args` 的脚本逻辑。

## 设计

新增仓库根目录 `Dockerfile`。

`builder` 阶段基于 Erlang/OTP Debian 镜像，安装 C/C++ 工具链、`git`、`libsnappy-dev` 等构建依赖，复制仓库源码并执行 `make rel`。该阶段只负责产出 `_build/default/rel/vernemq`，避免把构建工具链带入最终镜像。

`runtime` 阶段基于 `debian:bookworm-slim`，安装 VerneMQ 运行和健康检查所需的最小依赖，然后创建 `vernemq` 用户/组并复制 builder 阶段生成的 release 到 `/vernemq`。复制后统一调整目录归属，最后切换到非 root 用户运行。

启动命令使用：

```dockerfile
CMD ["vernemq", "console", "-noshell", "-noinput"]
```

该命令使用 release 自带 runner 在前台启动 broker，符合容器单进程模型，也能让 Docker 正确接收进程退出状态。

## 依赖选择

构建阶段使用 Erlang/OTP 26 对齐仓库 CI 中的默认 release 版本 `26.2`。仓库 README 说明当前 VerneMQ 支持 OTP 25-27，因此 Dockerfile 提供 `ARG OTP_VERSION=26`，后续可在构建时覆盖。

运行阶段保留官方镜像已有的运行依赖集合：`bash`、`procps`、`openssl`、`iproute2`、`curl`、`jq`、`libsnappy-dev`、`net-tools`。其中 `curl` 和 `jq` 对本次最小启动不是必需，但保留它们可以降低与官方镜像运行环境的差异。

## 错误处理与边界

- Docker 构建阶段如果依赖拉取、C 扩展编译或 release 生成失败，构建应直接失败。
- 最终镜像不包含源码构建目录和 rebar 缓存，减少镜像体积和运行时攻击面。
- 因未复制官方 `start_vernemq` 脚本，使用者如需动态配置，应通过挂载 `/vernemq/etc` 或构建派生镜像来提供配置文件。

## 验证

实现后至少执行：

- `docker build -t vernemq:source .`
- 如本机 Docker 可用，启动容器并检查健康命令或 `vernemq ping`。
- 如果 Docker 不可用，则至少执行 Dockerfile 静态检查和说明未能运行容器验证的原因。
