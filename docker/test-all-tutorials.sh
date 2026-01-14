#!/bin/bash
# Master test script - runs all tutorials sequentially
set -e

SCRIPT_DIR="$(dirname "$0")"

echo "========================================================"
echo "ClotFoam Tutorial Test Suite"
echo "========================================================"
echo ""

# Track results
PASSED=0
FAILED=0
RESULTS=""

run_test() {
    local test_script="$1"
    local test_name="$2"
    
    echo ""
    echo "--------------------------------------------------------"
    echo "Starting: $test_name"
    echo "--------------------------------------------------------"
    
    if bash "$test_script"; then
        PASSED=$((PASSED + 1))
        RESULTS="${RESULTS}✓ $test_name: PASSED\n"
        return 0
    else
        FAILED=$((FAILED + 1))
        RESULTS="${RESULTS}✗ $test_name: FAILED\n"
        return 1
    fi
}

# Run tests sequentially
# Each tutorial runs independently, failure doesn't stop others

echo "Running rectangle2D (baseline test)..."
run_test "$SCRIPT_DIR/test.sh" "rectangle2D" || true

echo "Running Tjunction2D..."
run_test "$SCRIPT_DIR/test-tjunction2d.sh" "Tjunction2D" || true

echo "Running Hjunction3D..."
run_test "$SCRIPT_DIR/test-hjunction3d.sh" "Hjunction3D" || true

# Summary
echo ""
echo "========================================================"
echo "TEST SUITE SUMMARY"
echo "========================================================"
echo -e "$RESULTS"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "========================================================"

# Exit with failure if any test failed
if [ $FAILED -gt 0 ]; then
    echo "Some tests failed!"
    exit 1
fi

echo "All tests passed!"
exit 0
