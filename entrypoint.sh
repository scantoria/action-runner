#!/usr/bin/env bash
set -euo pipefail

required_vars=(GITHUB_OWNER GITHUB_REPOSITORY RUNNER_TOKEN)
runner_configured=false
runner_pid=""

for var_name in "${required_vars[@]}"; do
    if [[ -z "${!var_name:-}" ]]; then
        echo "Missing required environment variable: ${var_name}" >&2
        exit 1
    fi
done

runner_name="${RUNNER_NAME:-$(hostname)}"
runner_labels="${RUNNER_LABELS:-self-hosted,linux,x64}"
runner_workdir="${RUNNER_WORKDIR:-_work}"
repo_url="https://github.com/${GITHUB_OWNER}/${GITHUB_REPOSITORY}"

cleanup() {
    if [[ -n "${runner_pid}" ]] && kill -0 "${runner_pid}" 2>/dev/null; then
        echo "Stopping runner..."
        kill -TERM "${runner_pid}" 2>/dev/null || true
        wait "${runner_pid}" 2>/dev/null || true
    fi

    if [[ "${runner_configured}" == "true" ]]; then
        echo "Removing runner registration..."
        ./config.sh remove --unattended --token "${RUNNER_TOKEN}" || true
    fi
}

handle_signal() {
    cleanup
    exit 0
}

trap handle_signal INT TERM
trap cleanup EXIT

./config.sh \
    --unattended \
    --url "${repo_url}" \
    --token "${RUNNER_TOKEN}" \
    --name "${runner_name}" \
    --labels "${runner_labels}" \
    --work "${runner_workdir}" \
    --replace

runner_configured=true

./run.sh &
runner_pid="$!"
wait "${runner_pid}"
