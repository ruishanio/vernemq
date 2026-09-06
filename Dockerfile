# syntax=docker/dockerfile:1

# VerneMQ 2.2.0 要求 OTP 27 及以上；OTP 28.5 镜像基于 Trixie，与运行阶段保持一致。
ARG OTP_VERSION=28.5

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

# 使用镜像中随当前 OTP 构建的 rebar3，避免仓库内预编译版本与 OTP 不兼容。
RUN /usr/local/bin/rebar3 version \
    && make rel REBAR=/usr/local/bin/rebar3

FROM debian:trixie-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        adduser \
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

ENV PATH="/vernemq/bin:${PATH}"

COPY --from=builder --chown=10000:10000 /build/vernemq/_build/default/rel/vernemq/ /vernemq/
COPY --chown=10000:10000 docker/vernemq.conf /vernemq/etc/vernemq.conf
COPY --chmod=0755 docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN ln -s /vernemq/etc /etc/vernemq \
    && ln -s /vernemq/data /var/lib/vernemq \
    && ln -s /vernemq/log /var/log/vernemq

EXPOSE 1883 8883 8080 44053 4369 8888 \
    9100 9101 9102 9103 9104 9105 9106 9107 9108 9109

VOLUME ["/vernemq/log", "/vernemq/data", "/vernemq/etc"]

HEALTHCHECK CMD vernemq ping | grep -q pong

USER vernemq

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
