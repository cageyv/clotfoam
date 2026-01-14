#!/bin/bash
# Test script for Hjunction3D tutorial
# Runs 5 timesteps to verify solver works (3D case may take longer)
set -e

TUTORIAL_NAME="Hjunction3D"
TUTORIAL_DIR="/home/ofuser/tutorials/$TUTORIAL_NAME"
TIMESTEPS_TARGET=5
TIMEOUT_SECONDS=900  # 15 min for 3D case

echo "================================================"
echo "Running $TUTORIAL_NAME tutorial test"
echo "================================================"

cd "$TUTORIAL_DIR"

# Clean previous results
rm -rf [1-9]* 0.* processor* log* postProcessing 2>/dev/null || true

# Run blockMesh
echo "Running blockMesh..."
blockMesh > log.blockMesh 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: blockMesh failed"
    cat log.blockMesh
    exit 1
fi
echo "✓ blockMesh completed"

# Create test controlDict (5 timesteps, short endTime)
cp system/controlDict system/controlDict.orig
cat > system/controlDict << 'EOF'
/*--------------------------------*- C++ -*----------------------------------*\
  =========                 |
  \\      /  F ield         | OpenFOAM: The Open Source CFD Toolbox
   \\    /   O peration     | Website:  https://openfoam.org
    \\  /    A nd           | Version:  12
     \\/     M anipulation  |
\*---------------------------------------------------------------------------*/
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    location    "system";
    object      controlDict;
}

application     clotFoam;
coagReactionsOn true;
smoothHadh      false;
startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         0.00025;
deltaT          0.00005;
writeControl    timeStep;
writeInterval   1;
purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable false;
adjustTimeStep  no;
maxCo           0.75;
maxDeltaT       0.0001;
EOF

# Run solver (disable set -e to capture exit code)
echo "Running clotFoam ($TIMESTEPS_TARGET timesteps)..."
set +e
timeout $TIMEOUT_SECONDS clotFoam > log.clotFoam 2>&1
SOLVER_EXIT=$?
set -e

# Restore original controlDict
mv system/controlDict.orig system/controlDict

echo "clotFoam exit code: $SOLVER_EXIT"

# Validate results
if ! grep -q "Create mesh for time" log.clotFoam; then
    echo "ERROR: Solver failed to initialize"
    head -100 log.clotFoam
    exit 1
fi

if [ $SOLVER_EXIT -eq 124 ]; then
    echo "ERROR: Solver timed out"
    tail -50 log.clotFoam
    exit 1
elif [ $SOLVER_EXIT -ne 0 ]; then
    echo "ERROR: Solver failed"
    tail -50 log.clotFoam
    exit 1
fi

if ! grep -q "^End" log.clotFoam; then
    echo "ERROR: No 'End' marker found"
    tail -50 log.clotFoam
    exit 1
fi

TIMESTEPS=$(grep -c "^Time = " log.clotFoam || echo "0")
echo "✓ Completed $TIMESTEPS timesteps"

if [ $TIMESTEPS -lt 3 ]; then
    echo "ERROR: Expected at least 3 timesteps"
    exit 1
fi

# Check output directory
LATEST_TIME=$(ls -d [0-9]* 2>/dev/null | grep -v "^0$" | sort -n | tail -1 || true)
if [ -n "$LATEST_TIME" ]; then
    echo "✓ Output directory: $LATEST_TIME"
else
    echo "WARNING: No output directory found"
fi

echo ""
echo "================================================"
echo "$TUTORIAL_NAME test PASSED"
echo "================================================"
