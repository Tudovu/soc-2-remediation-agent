#!/usr/bin/env bash
# Run a SOC 2 compliance scan with Prowler.
# Requires: Python 3.11–3.13 (Prowler may fail on 3.14), AWS credentials via AWS_PROFILE
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "${AWS_PROFILE:-}" ]]; then
  echo "Set AWS_PROFILE (e.g. export AWS_PROFILE=your-profile)" >&2
  exit 1
fi

if [[ ! -d .venv ]]; then
  echo "Creating venv with python3.12..."
  python3.12 -m venv .venv
  .venv/bin/pip install -q prowler
fi

mkdir -p prowler/output
.venv/bin/prowler aws \
  --compliance soc2_aws \
  --output-formats json-ocsf csv \
  --output-directory ./prowler/output \
  "$@"

echo ""
echo "Latest output in prowler/output/"
