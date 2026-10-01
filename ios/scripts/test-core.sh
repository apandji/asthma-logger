#!/usr/bin/env bash
# Runs AsthmaCore's tests. Uses a local Swift toolchain (Mac, or Linux with Swift) and falls back to
# Docker in cloud sessions where swift.org downloads are blocked.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO="$(cd .. && pwd)"

if command -v swift >/dev/null 2>&1; then
  (cd AsthmaCore && swift test "$@")
  exit
fi

if ! docker info >/dev/null 2>&1; then
  (dockerd >/tmp/dockerd.log 2>&1 &)
  for _ in $(seq 1 20); do docker info >/dev/null 2>&1 && break; sleep 1; done
fi
IMAGE="mirror.gcr.io/library/swift:6.1-noble"
docker image inspect "$IMAGE" >/dev/null 2>&1 || docker pull -q "$IMAGE"
docker run --rm -v "$REPO":/repo -w /repo/ios/AsthmaCore "$IMAGE" swift test "$@"
