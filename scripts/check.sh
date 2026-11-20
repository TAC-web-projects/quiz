#!/usr/bin/env bash
# Render the site and fail loudly on any quiz-filter, Quarto, pandoc or TikZ problem.
#
#   scripts/check.sh              render the real site (index.qmd -> docs/)
#   scripts/check.sh --templates  also check that topic/_template/ still renders
#
# Malformed question files (missing `type:`, an answer symbol that isn't on the
# keyboard, a memory row without $...$ math, ...) stop the render with a
# "[quiz] <file>: <problem>" message, so this script catches them too.
set -uo pipefail
cd "$(dirname "$0")/.."

# Known harmless noise from Inkscape (used by the TikZ filter) in headless containers.
NOISE='GtkRecentManager|^\*\* \(inkscape|^$'

render() {
  local log
  log=$(mktemp)
  quarto render "$@" >"$log" 2>&1
  local status=$?
  local problems
  problems=$(grep -vE "$NOISE" "$log" | grep -iE 'error|warn|\[quiz\]|undefined control sequence|emergency stop' || true)
  if [ $status -ne 0 ] || [ -n "$problems" ]; then
    echo "✗ quarto render $* failed (exit $status):"
    if [ -n "$problems" ]; then echo "$problems"; else grep -vE "$NOISE" "$log" | tail -30; fi
    rm -f "$log"
    return 1
  fi
  rm -f "$log"
  echo "✓ quarto render $*"
}

if [ "${1:-}" = "--templates" ]; then
  # Render a throwaway page that uses topic/_template/ as a topic, then delete
  # its output. (Done first: the full render below rebuilds docs/ cleanly.)
  tmp="check-templates.qmd"
  trap 'rm -f "$tmp" check-templates.html docs/check-templates.html; rm -rf check-templates_files docs/check-templates_files' EXIT
  printf -- '---\ntitle: Template check\n---\n\n::: {.topic folder="topic/_template" title="Template"}\n:::\n' >"$tmp"
  render "$tmp" || exit 1
  rm -f "$tmp" check-templates.html docs/check-templates.html
fi

render || exit 1

echo "All checks passed."
