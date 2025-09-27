#!/bin/bash
# Verify ShellCheck compliance for project scripts
# This script mimics what CI will run

set -euo pipefail

echo "=== Verifying ShellCheck compliance for project scripts ==="
echo

# Get list of scripts to check
mapfile -t scripts < <(find . -type f -name "*.sh" \
  -not -path "./node_modules/*" \
  -not -path "./nodes/node_modules/*" \
  -not -path "./data/*" \
  -not -path "./.git/*" \
  -not -path "./logs/*" 2>/dev/null)

total_scripts=${#scripts[@]}
echo "Found $total_scripts shell scripts to check"
echo

if [ "$total_scripts" -eq 0 ]; then
  echo "No shell scripts found to check"
  exit 0
fi

# Run ShellCheck on each script
failed=0
for i in "${!scripts[@]}"; do
  script="${scripts[$i]}"
  echo "[$((i+1))/$total_scripts] Checking $script..."
  
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