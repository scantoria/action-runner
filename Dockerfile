FROM ubuntu:24.04

ARG RUNNER_VERSION=2.328.0

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gzip \
        tar \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash runner \
    && mkdir -p /actions-runner \
    && chown -R runner:runner /actions-runner /home/runner

WORKDIR /actions-runner

RUN curl -fsSL \
        -o actions-runner.tar.gz \
        "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" \
    && tar xzf actions-runner.tar.gz \
    && rm actions-runner.tar.gz \
    && ./bin/installdependencies.sh \
    && chown -R runner:runner /actions-runner

COPY --chown=runner:runner --chmod=755 entrypoint.sh /entrypoint.sh

USER runner

ENTRYPOINT ["/entrypoint.sh"]
