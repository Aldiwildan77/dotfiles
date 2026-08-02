#!/usr/bin/env bash
# Thin wrapper kept for muscle memory. All the work lives in install/.
#
#   ./setup.sh              # everything
#   ./setup.sh packages     # OS packages only
#   ./setup.sh --help       # stage list and env vars
exec bash "$(cd "$(dirname "$0")" && pwd)/install/bootstrap.sh" "$@"
