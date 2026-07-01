#!/usr/bin/env bash
# Managed-policy size lint.
#
# AWS caps a single customer-managed IAM policy at 6144 characters (whitespace excluded — IAM
# measures the policy document after stripping insignificant whitespace). The deploy-role permission
# set is split across four functional authoritative policy files, each rendered into its own managed
# policy:
#
#   EntHomeAccess.compute-network.json        -> EntHomeAccessCompute
#   EntHomeAccess.data-storage.json           -> EntHomeAccessData
#   EntHomeAccess.identity-security.json      -> EntHomeAccessSecurity
#   EntHomeAccess.observability-platform.json -> EntHomeAccessPlatform
#
# This check fails the build the moment any one file's non-whitespace length crosses THRESHOLD (set
# below 6144 for headroom), turning the otherwise opaque apply-time `LimitExceeded` / `PolicyDocument
# ... exceeds maximum allowed size` into a clear PR-time failure that names the offending file and its
# size.
#
# Usage: scripts/check-policy-size.sh
# Run from the repo root (CI does). Exits non-zero on any violation.

set -euo pipefail

# jq canonicalizes each policy to compact JSON so the measured size matches what AWS counts (formatting
# whitespace removed, string contents kept). Required on PATH.
command -v jq >/dev/null 2>&1 || { echo "check-policy-size: requires 'jq' on PATH" >&2; exit 1; }

# Margin under AWS's 6144-character hard limit. A file at or above this fails the build.
THRESHOLD=6000
AWS_LIMIT=6144

# The functional policy files (one managed policy each). Globs EntHomeAccess.<domain>.json; a new
# functional file is picked up automatically.
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

policy_files=()
for f in EntHomeAccess.*.json; do
  [ -e "$f" ] || continue
  policy_files+=("$f")
done

if [ "${#policy_files[@]}" -eq 0 ]; then
  echo "check-policy-size: no policy files found (expected EntHomeAccess.<domain>.json at repo root)" >&2
  exit 1
fi

# Policy size as AWS measures it: the document with insignificant (formatting) whitespace removed but
# whitespace INSIDE string values kept (it is significant and counted). `jq -c` emits exactly that
# compact form; stripping all whitespace would drop in-string spaces and undercount, risking a false
# pass. Count characters of the compact JSON (policies are ASCII, so bytes == chars).
policy_size() {
  jq -c . "$1" | tr -d '\n' | wc -c | tr -d ' '
}

status=0
echo "Managed-policy size check (threshold ${THRESHOLD}, AWS hard limit ${AWS_LIMIT}, compact-JSON chars):"
for f in "${policy_files[@]}"; do
  len="$(policy_size "$f")"
  if [ "$len" -ge "$THRESHOLD" ]; then
    printf '  FAIL  %-42s %5s chars  >= threshold %s (AWS limit %s)\n' "$f" "$len" "$THRESHOLD" "$AWS_LIMIT"
    status=1
  else
    printf '  ok    %-42s %5s chars  (< %s)\n' "$f" "$len" "$THRESHOLD"
  fi
done

if [ "$status" -ne 0 ]; then
  echo "" >&2
  echo "ERROR: one or more policy files meet or exceed ${THRESHOLD} non-whitespace characters." >&2
  echo "A single AWS customer-managed policy cannot exceed ${AWS_LIMIT} characters. Rebalance the" >&2
  echo "functional grouping (move statements to a less-full domain file) or add a new functional file" >&2
  echo "plus a matching statement group + aws_iam_policy in terraform/modules/deploy-permissions, and" >&2
  echo "attach it via the module's policy_arns output." >&2
  exit 1
fi

echo "All policy files are under the ${THRESHOLD}-character threshold."
