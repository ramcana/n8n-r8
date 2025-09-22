#!/bin/bash
# Verify ShellCheck compliance for project scripts
# This script mimics what CI will run

set -euo pipefail

echo "=== Verifying ShellCheck compliance for project scripts ==="
echo

# Count total scripts
total_scripts=$(find . -type f -name "*.sh" \
  -not -path "./node_modules/*" \
  -not -path "./nodes/node_modules/*" \
  -not -path "./data/*" \
  -not -path "./.git/*" \
  -not -path "./logs/*" 2>/dev/null | wc -l)

echo "Found $total_scripts shell scripts to check"
echo

# Run ShellCheck on project scripts only
failed=0
checked=0

find . -type f -name "*.sh" \
  -not -path "./node_modules/*" \
  -not -path "./nodes/node_modules/*" \
  -not -path "./data/*" \
  -not -path "./.git/*" \
  -not -path "./logs/*" \
  -print0 2>/dev/null | while IFS= read -r -d '' script; do
  
  checked=$((checked + 1))
  echo "[$checked/$total_scripts] Checking $script..."
  
  if shellcheck -x "$script"; then
    echo "✓ PASSED"
  else
    echo "✗ FAILED"
    failed=$((failed + 1))
  fi
  echo
done

if [ $failed -eq 0 ]; then
  echo "🎉 All $total_scripts shell scripts passed ShellCheck!"
  exit 0
else
  echo "❌ $failed out of $total_scripts scripts failed ShellCheck"
  exit 1
fi