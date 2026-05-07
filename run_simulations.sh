#!/bin/bash

# Script to compile and run Stokes flow solver with different Reynolds numbers
# Usage: ./run_simulations.sh [Re1] [Re2] ...
# Example: ./run_simulations.sh 0.01 0.1 1.0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default Reynolds numbers if none provided
if [ $# -eq 0 ]; then
    REYNOLDS_NUMBERS=(0.01 0.1 1.0)
else
    REYNOLDS_NUMBERS=("$@")
fi

echo -e "${BLUE}=== Stokes Flow Solver - Multi-Reynolds Number Simulations ===${NC}\n"

# Create output directory
mkdir -p simulations
cd simulations

# Compile base code for each Reynolds number
for Re in "${REYNOLDS_NUMBERS[@]}"; do
    echo -e "${BLUE}Compiling for Reynolds = ${Re}${NC}"
    
    OUTPUT_DIR="Re_${Re}"
    mkdir -p "$OUTPUT_DIR"
    cd "$OUTPUT_DIR"
    
    # Copy source code
    cp ../../stokes_sphere.c .
    
    # Compile with specific Reynolds number
    qcc -O2 -DREYNOLDS="$Re" -DLEVEL_MAX=8 -DMAX_TIME=50 \
        stokes_sphere.c -o stokes_sphere -lm 2>&1 | tee compile.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}✓ Compilation successful for Re=${Re}${NC}\n"
        
        echo -e "${BLUE}Running simulation for Reynolds = ${Re}${NC}"
        ./stokes_sphere > simulation.log 2>&1 &
        PID=$!
        echo -e "Process ID: ${PID}\n"
        
    else
        echo -e "${RED}✗ Compilation failed for Re=${Re}${NC}\n"
    fi
    
    cd ..
done

echo -e "${GREEN}All simulations submitted!${NC}"
echo "Monitor progress with: tail -f Re_*/simulation.log"
echo "Results will be in Re_*/drag_history.txt and Re_*/output-*.vtu"
