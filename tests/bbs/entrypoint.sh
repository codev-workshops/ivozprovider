#!/bin/bash
#
# Run every BBS scenario once and leave one JUnit file per scenario in
# ${RESULTS_DIR}. Meant to be run inside the image built from this directory's
# Dockerfile, with the repository mounted at /opt/irontec/ivozprovider.
#
#   NAMESERVER   resolver that knows the SIP domains (required by bbs)
#   RESULTS_DIR  where the per-scenario JUnit files are written
#   ATTEMPTS     how many times a scenario may be retried before it counts as
#                failed. Defaults to 1: a scenario that only passes on a retry
#                is a flaky scenario and the baseline needs to see that.
#   SCENARIOS    override the scenario glob
#
# Exits non-zero if any scenario failed.

NAMESERVER=${NAMESERVER:-127.0.0.11}
RESULTS_DIR=${RESULTS_DIR:-results/bbs}
ATTEMPTS=${ATTEMPTS:-1}

mkdir -p "${RESULTS_DIR}"

failed=0
for TEST in ${SCENARIOS:-$(ls -1 tests/bbs/*test-*.yaml)}; do
    TESTNAME=$(basename "${TEST%.*}")
    OUT="${RESULTS_DIR}/results_${TESTNAME}.xml"
    rm -f "$OUT"

    for _ in $(seq "${ATTEMPTS}"); do
        bbs --nameserver "${NAMESERVER}" -c "$TEST" -e tests/bbs/environment.yaml -o "$OUT" && break
    done || { failed=$((failed + 1)); echo "FAILED: ${TESTNAME}" >&2; }

    sleep 2
done

exit $((failed > 0))
