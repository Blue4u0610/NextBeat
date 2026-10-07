#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
swiftc Shared/PlanModels.swift Shared/PlanEngine.swift Shared/PlanStorage.swift Shared/PreviewFixtures.swift Tests/CoreHarness/main.swift -o "$tmpdir/nextbeat-core-checks"
"$tmpdir/nextbeat-core-checks"
