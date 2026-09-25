#!/usr/bin/env bash
set -euo pipefail

# nixos-config deployment helper
# Builds on remote x86_64 builder ('indulgence') to avoid slow emulation / compilation on Apple Silicon (ARM64).

HOST="${1:-}"
ACTION="${2:-switch}"
BUILD_HOST="${BUILD_HOST:-indulgence}"

if [ -z "$HOST" ]; then
  echo "Usage: $0 <host> [switch|boot|test|build] [extra nixos-rebuild flags...]"
  echo ""
  echo "Available hosts in flake:"
  echo "  akira, bimbo, immich, latte, loona, maid, rei"
  echo ""
  echo "Examples:"
  echo "  $0 maid switch               # Build on indulgence, deploy to maid"
  echo "  $0 maid switch -S            # Ask for sudo password (if passwordless sudo is not yet active)"
  echo "  $0 maid build                # Build on indulgence and save result locally"
  echo "  $0 rei switch                # Rebuild local machine rei"
  exit 1
fi

EXTRA_ARGS=("${@:3}")

if [ "$HOST" = "rei" ]; then
  echo "==> Rebuilding local host '$HOST' ($ACTION)..."
  sudo nixos-rebuild "$ACTION" --flake ".#$HOST" "${EXTRA_ARGS[@]}"
else
  echo "==> Deploying '$HOST' ($ACTION) using remote build host '$BUILD_HOST'..."
  nixos-rebuild "$ACTION" \
    --flake ".#$HOST" \
    --target-host "$HOST" \
    --build-host "$BUILD_HOST" \
    --use-substitutes \
    "${EXTRA_ARGS[@]}"
fi
