#!/bin/bash
#
# Run every BBS scenario once and leave one JUnit file per scenario in
# ${RESULTS_DIR}. Meant to be run inside the image built from this directory's
# Dockerfile, with the repository mounted at /opt/irontec/ivozprovider.
#
#   NAMESERVER   resolver that knows the SIP domains (required by bbs)
#   RESULTS_DIR  where the per-scenario JUnit files are written
#   ATTEMPTS     how many times a scenario may be tried before it counts as
#                failed. A scenario that only passes on a retry is recorded as
#                flaky rather than as a clean pass - the attempt count is left
#                next to its JUnit file.
#   SCENARIOS    override the scenario glob
#
# Exits non-zero if any scenario failed.

NAMESERVER=${NAMESERVER:-127.0.0.11}
RESULTS_DIR=${RESULTS_DIR:-results/bbs}
ATTEMPTS=${ATTEMPTS:-3}
SETTLE=${SETTLE:-5}

mkdir -p "${RESULTS_DIR}"

failed=0
for TEST in ${SCENARIOS:-$(ls -1 tests/bbs/*test-*.yaml)}; do
    TESTNAME=$(basename "${TEST%.*}")
    OUT="${RESULTS_DIR}/results_${TESTNAME}.xml"
    rm -f "$OUT"

    for attempt in $(seq "${ATTEMPTS}"); do
        echo "$attempt" > "${RESULTS_DIR}/attempts_${TESTNAME}.txt"
        bbs --nameserver "${NAMESERVER}" -c "$TEST" -e tests/bbs/environment.yaml -o "$OUT" && break
        echo "attempt ${attempt}/${ATTEMPTS} failed: ${TESTNAME}" >&2
        sleep "${SETTLE}"
    done || { failed=$((failed + 1)); echo "FAILED: ${TESTNAME}" >&2; }

    # Let registrations and dialogs from the previous scenario expire, so the
    # next one does not inherit them.
    sleep "${SETTLE}"
done

exit $((failed > 0))
