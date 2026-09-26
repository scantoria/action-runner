# action-runner

Docker image for running a self-hosted GitHub Actions runner.

## Configuration

Copy `.env.example` to `.env` and fill in `RUNNER_TOKEN` with a GitHub Actions runner registration token for the target repository.

Required environment variables:

- `GITHUB_OWNER`
- `GITHUB_REPOSITORY`
- `RUNNER_TOKEN`

Optional environment variables:

- `RUNNER_NAME`
- `RUNNER_LABELS`
- `RUNNER_WORKDIR`

## Build

```sh
docker build -t action-runner .
```

## Run

```sh
docker run --rm --env-file .env action-runner
```
