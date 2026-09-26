#!/usr/bin/env bash
set -euo pipefail

required_vars=(GITHUB_OWNER GITHUB_REPOSITORY RUNNER_TOKEN)

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
    echo "Removing runner registration..."
    ./config.sh remove --unattended --token "${RUNNER_TOKEN}" || true
}

trap cleanup EXIT INT TERM

./config.sh \
    --unattended \
    --url "${repo_url}" \
    --token "${RUNNER_TOKEN}" \
    --name "${runner_name}" \
    --labels "${runner_labels}" \
    --work "${runner_workdir}" \
    --replace

exec ./run.sh
