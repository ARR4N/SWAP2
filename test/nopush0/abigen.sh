#!/usr/bin/env bash

set -eu;

ROOT=$(git rev-parse --show-toplevel);
PROPOSER="${ROOT}/out/SWAP2.sol/SWAP2Proposer.json";

abigen \
    --pkg nopush0 \
    --abi <(cat "${PROPOSER}" | jq ".abi") \
    --bin=<(cat "${PROPOSER}" | jq -r ".bytecode.object") > generated_test.go;