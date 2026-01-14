#!/bin/bash
set -e

echo "================================================"
echo "OpenFOAM Environment Check"
echo "================================================"
echo "WM_PROJECT_VERSION: $WM_PROJECT_VERSION"
echo "FOAM_USER_APPBIN: $FOAM_USER_APPBIN"
echo "================================================"

# Compile clotFoam
echo ""
echo "================================================"
echo "Compiling clotFoam solver..."
echo "================================================"
cd /home/ofuser/clotFoam
wclean
wmake

# Verify the executable was created
if [ ! -f "$FOAM_USER_APPBIN/clotFoam" ]; then
    echo "ERROR: clotFoam executable not found at $FOAM_USER_APPBIN/clotFoam"
    exit 1
fi

echo ""
echo "================================================"
echo "Compilation successful!"
echo "================================================"

# Run rectangle2D tutorial
echo ""
echo "================================================"
echo "Running rectangle2D tutorial..."
echo "================================================"
cd /home/ofuser/tutorials/rectangle2D

# Clean any previous results
rm -rf [1-9]* 0.* processor* log* postProcessing 2>/dev/null || true

# Run blockMesh
echo "Running blockMesh..."
blockMesh > log.blockMesh 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: blockMesh failed"
    cat log.blockMesh
    exit 1
fi

# Modify controlDict to run limited timesteps for testing
cp system/controlDict system/controlDict.orig
cat > system/controlDict << 'EOF'
FoamFile
{
    version     2.0;
    format      ascii;
    class       dictionary;
    location    "system";
    object      controlDict;
}

application     clotFoam;
startFrom       startTime;
startTime       0;
stopAt          endTime;
endTime         0.05;
deltaT          0.0001;
writeControl    timeStep;
writeInterval   100;
purgeWrite      0;
writeFormat     ascii;
writePrecision  6;
writeCompression off;
timeFormat      general;
timePrecision   6;
runTimeModifiable true;
adjustTimeStep  yes;
maxCo           0.25;
maxDeltaT       0.001;
EOF

# Run clotFoam
echo "Running clotFoam (limited timesteps for testing)..."
clotFoam > log.clotFoam 2>&1
CLOTFOAM_EXIT=$?

# Restore original controlDict
mv system/controlDict.orig system/controlDict

# Check exit code
if [ $CLOTFOAM_EXIT -ne 0 ]; then
    echo "ERROR: clotFoam failed with exit code $CLOTFOAM_EXIT"
    echo "Last 50 lines of log:"
    tail -50 log.clotFoam
    exit 1
fi

# Verify output was generated
if [ ! -d "0.05" ]; then
    echo "WARNING: Expected output directory 0.05 not found, checking for any time directories..."
    LATEST_TIME=$(ls -d [0-9]* 2>/dev/null | sort -n | tail -1)
    if [ -z "$LATEST_TIME" ]; then
        echo "ERROR: No time directories found - simulation may not have run"
        cat log.clotFoam
        exit 1
    fi
    echo "Found time directory: $LATEST_TIME"
fi

echo ""
echo "================================================"
echo "All tests passed successfully!"
echo "================================================"
