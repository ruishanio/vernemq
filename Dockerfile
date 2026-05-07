# syntax=docker/dockerfile:1

ARG OTP_VERSION=26

FROM erlang:${OTP_VERSION}-bookworm AS builder

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
