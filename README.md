# ThisByte GitHub Actions runner

Containerized self-hosted GitHub Actions runner for the private
`scantoria/thisbyte-website` repository.

Architecture:

```text
Windows HP workstation
-> Docker Desktop with WSL2/Linux containers
-> Linux GitHub Actions runner container
-> future restricted SSH deployment to station-01 nginx
```

This project intentionally does not include deployment SSH credentials or mount
the Docker socket.

## Configuration

Copy `.env.example` to `.env` and fill in `RUNNER_TOKEN` with a GitHub Actions
runner registration token for the target repository. The token is supplied only
at runtime and is not baked into the image.

Required environment variables:

- `GITHUB_OWNER`
- `GITHUB_REPOSITORY`
- `RUNNER_TOKEN`

Optional environment variables:

- `RUNNER_NAME`
- `RUNNER_LABELS`
- `RUNNER_WORKDIR`

Default target configuration:

- Owner: `scantoria`
- Repository: `thisbyte-website`
- Runner name: `thisbyte-hp-runner`
- Labels: `self-hosted,linux,x64,thisbyte`

## Build

```sh
docker compose build
```

## Validate Without Registering

These commands do not contact GitHub for runner registration:

```sh
docker compose config
docker compose build
docker image inspect thisbyte/actions-runner:2.328.0
```

## Register And Run Later

After approval, create `.env` from `.env.example`, add a short-lived repository
runner registration token, then start the service:

```sh
docker compose up -d
```

The entrypoint configures the runner at container startup, runs it as the
non-root `runner` user, and attempts clean deregistration on shutdown.
