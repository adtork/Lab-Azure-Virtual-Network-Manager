#!/usr/bin/env bash
set -euo pipefail

RG=${RG:-avnm-lab-microhack}
CONFIRM_DELETE=${CONFIRM_DELETE:-false}

if [[ "$CONFIRM_DELETE" != "true" ]]; then
  printf 'This will delete resource group %s and all lab resources. Type %s to continue: ' "$RG" "$RG"
  read -r answer
  if [[ "$answer" != "$RG" ]]; then
    printf 'Cleanup cancelled.\n'
    exit 0
  fi
fi

az group delete -n "$RG" --yes --no-wait
printf 'Deletion submitted for resource group %s.\n' "$RG"
