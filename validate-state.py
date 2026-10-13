#!/usr/bin/env python3
"""Validate local runner state without network access or printing its contents."""
import base64
import json
import math
import pathlib
import sys
from urllib.parse import urlsplit


def require(condition, diagnostic):
    if not condition:
        raise ValueError(diagnostic)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON property; ambiguous state requires review.")
        result[key] = value
    return result


def load(path):
    try:
        def reject_constant(_):
            raise ValueError("Non-finite JSON constant is invalid state.")
        value = json.loads(path.read_text(), object_pairs_hook=unique_object,
                           parse_constant=reject_constant)
        require(isinstance(value, dict), "Expected a JSON object.")
        return value
    except (ValueError, OSError, UnicodeError):
        raise ValueError(f"Malformed {path.name}; preserve the file for administrative review.") from None


def https_url(value):
    if not isinstance(value, str):
        return False
    url = urlsplit(value)
    return url.scheme == "https" and bool(url.hostname) and not url.username and not url.password


def main():
    state = pathlib.Path(sys.argv[1])
    repo_url, name = sys.argv[2:4]
    for filename in (".runner", ".runner_migrated"):
        path = state / filename
        if filename == ".runner_migrated" and not path.exists():
            continue
        runner = load(path)
        require(
            all(type(runner.get(key)) is int and runner[key] > 0 for key in ("agentId", "poolId"))
            and runner.get("agentName") == name
            and isinstance(runner.get("gitHubUrl"), str)
            and runner["gitHubUrl"].rstrip("/") == repo_url
            and https_url(runner.get("serverUrl"))
            and runner.get("workFolder") == "_work"
            and runner.get("disableUpdate") is True
            and (runner.get("ephemeral") is None or runner.get("ephemeral") is False),
            f"Malformed or inconsistent {filename}; check identity, persistent mode, workspace, and disableUpdate.",
        )
    for filename in (".credentials", ".credentials_migrated"):
        path = state / filename
        if not path.exists():
            continue
        credentials = load(path)
        data = credentials.get("data")
        require(
            credentials.get("scheme") == "OAuth" and isinstance(data, dict)
            and isinstance(data.get("clientId"), str) and bool(data["clientId"])
            and https_url(data.get("authorizationUrl")),
            f"Malformed {filename}; do not regenerate or overwrite credentials automatically.",
        )
    raw_key = load(state / ".credentials_rsaparams")
    try:
        key = {}
        for field in ("d", "dp", "dq", "exponent", "inverseQ", "modulus", "p", "q"):
            raw = base64.b64decode(raw_key[field], validate=True)
            require(bool(raw), "Empty RSA field.")
            key[field] = int.from_bytes(raw, "big")
        p, q, d, e = (key[field] for field in ("p", "q", "d", "exponent"))
        require(p > 1 and q > 1 and p != q and e >= 3 and e % 2 == 1 and d > 0, "Invalid RSA fields.")
        require(key["modulus"].bit_length() >= 2048 and key["modulus"] == p * q, "Invalid RSA modulus.")
        require(key["dp"] == d % (p - 1) and key["dq"] == d % (q - 1), "Invalid RSA exponents.")
        require(q * key["inverseQ"] % p == 1 and d * e % math.lcm(p - 1, q - 1) == 1, "Inconsistent RSA key.")
    except (KeyError, TypeError, ValueError):
        raise ValueError("Malformed RSA credential state; administrative recovery is required.") from None
    for line in (state / ".env").read_text().splitlines():
        variable = line.partition("=")[0].upper()
        require(variable not in {"RUNNER_TOKEN", "RUNNER_REMOVE_TOKEN", "ACTIONS_RUNNER_INPUT_TOKEN"},
                "Runtime administrative token must not be persisted in the runner environment snapshot.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, UnicodeError):
        # Detailed, bounded diagnostics contain only fixed descriptions/filenames.
        print(str(sys.exception()), file=sys.stderr)
        sys.exit(1)
