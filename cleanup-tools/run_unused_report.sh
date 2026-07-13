#!/usr/bin/env bash
# Regenerate the Psalm unused-class dataset + tiered candidate report for a
# single component (default: library). Run from the repo root.
#
#   ./cleanup-tools/run_unused_report.sh [component]
#
set -euo pipefail

COMPONENT="${1:-library}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [ ! -f "$COMPONENT/vendor/bin/psalm" ]; then
  echo "Installing composer deps for $COMPONENT ..."
  ( cd "$COMPONENT" && composer install --no-interaction --no-scripts --no-plugins --prefer-dist \
      --ignore-platform-req=ext-mailparse --ignore-platform-req=ext-pcntl \
      --ignore-platform-req=ext-swoole --ignore-platform-req=ext-redis )
fi

echo "Running Psalm unused-code analysis on $COMPONENT ..."
php -d memory_limit=-1 "$COMPONENT/vendor/bin/psalm" \
  --config="$COMPONENT/psalm-unused.xml" \
  --no-cache --no-progress \
  --report="$REPO_ROOT/psalm-unused.json" \
  --report-show-info=false || true   # non-zero exit is expected (issues found)

echo "Tiering candidates ..."
python3 cleanup-tools/tier_candidates.py \
  --repo . --report psalm-unused.json --component "$COMPONENT" \
  --out-csv unused_candidates.csv --out-json unused_candidates.json

echo "Done. See unused_candidates.csv"
