#!/bin/bash

# Parallel script to run Stokes flow solver with different Reynolds numbers
# Supports OpenMP and MPI parallelization
#
# Usage:
#   ./run_simulations.sh [Re1] [Re2] ... [--cores N] [--mode MODE]
#
# Examples:
#   ./run_simulations.sh 0.01 0.1 1.0 --cores 10 --mode openmp
#   ./run_simulations.sh 0.01 0.1 1.0 --cores 10 --mode mpi
#   ./run_simulations.sh 0.01 0.1 1.0  # Default: openmp with 10 cores

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Default parameters
REYNOLDS_NUMBERS=(0.01 0.1 1.0)
NUM_CORES=10
MODE="openmp"
LEVEL_MAX=8
MAX_TIME=50

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cores)
            NUM_CORES=$2
            shift 2
            ;;
        --mode)
            MODE=$2
            shift 2
            ;;
        --help)
            echo "Usage: $0 [Re1] [Re2] ... [--cores N] [--mode MODE]"
            echo ""
            echo "Reynolds numbers: Space-separated list (default: 0.01 0.1 1.0)"
            echo "Options:"
            echo "  --cores N       Number of cores/processes (default: 10)"
            echo "  --mode MODE     openmp or mpi (default: openmp)"
            echo ""
            echo "Examples:"
            echo "  $0 0.001 0.01 0.1 1.0 --cores 10 --mode openmp"
            echo "  $0 0.1 1.0 --cores 8 --mode mpi"
            exit 0
            ;;
        -[0-9]*)
            # Negative number (Re value)
            REYNOLDS_NUMBERS=($1)
            shift
            ;;
        *)
            if ! [[ "$1" =~ ^-- ]]; then
                REYNOLDS_NUMBERS+=("$1")
            fi
            shift
            ;;
    esac
done

# If no Reynolds numbers specified, use defaults
if [ ${#REYNOLDS_NUMBERS[@]} -eq 0 ]; then
    REYNOLDS_NUMBERS=(0.01 0.1 1.0)
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Stokes Flow Solver - Parallel Parameter Study        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}Configuration:${NC}"
echo "  Mode: $MODE"
echo "  Cores/Processes: $NUM_CORES"
echo "  Mesh level: $LEVEL_MAX"
echo "  Max time: $MAX_TIME"
echo "  Reynolds numbers: ${REYNOLDS_NUMBERS[@]}"
echo ""

# Create output directory
mkdir -p simulations
cd simulations

# Counter for background jobs
job_count=0
max_parallel_jobs=2  # Run at most 2 simulations in parallel to avoid overload

echo -e "${YELLOW}Starting simulations...${NC}"
echo ""

for Re in "${REYNOLDS_NUMBERS[@]}"; do
    OUTPUT_DIR="Re_${Re}"
    mkdir -p "$OUTPUT_DIR"
    cd "$OUTPUT_DIR"
    
    echo -e "${BLUE}Setting up Reynolds = $Re${NC}"
    
    # Copy source code
    cp ../../stokes_sphere.c .
    
    # Compile based on mode
    case $MODE in
        openmp)
            echo "  Compiling with OpenMP..."
            qcc -O2 -DREYNOLDS="$Re" -DLEVEL_MAX="$LEVEL_MAX" -DMAX_TIME="$MAX_TIME" \
                stokes_sphere.c -o stokes_sphere -lm -fopenmp 2>&1 | grep -E "Error|error|error:" || true
            
            echo "  Running with $NUM_CORES OpenMP threads..."
            (
                export OMP_NUM_THREADS=$NUM_CORES
                ./stokes_sphere > simulation.log 2>&1
            ) &
            ;;
        
        mpi)
            echo "  Compiling with MPI..."
            if ! mpicc -O2 -DREYNOLDS="$Re" -DLEVEL_MAX="$LEVEL_MAX" -DMAX_TIME="$MAX_TIME" \
                stokes_sphere.c -o stokes_sphere -lm 2>&1; then
                echo -e "${RED}  ✗ MPI compilation failed for Re=$Re${NC}"
                cd ..
                continue
            fi
            
            echo "  Running with $NUM_CORES MPI processes..."
            (
                mpirun -np $NUM_CORES ./stokes_sphere > simulation.log 2>&1
            ) &
            ;;
        
        *)
            echo -e "${RED}Unknown mode: $MODE${NC}"
            cd ..
            continue
            ;;
    esac
    
    PID=$!
    echo -e "${GREEN}  ✓ Submitted (PID: $PID)${NC}"
    
    cd ..
    
    # Limit parallel jobs
    job_count=$((job_count + 1))
    if [ $job_count -ge $max_parallel_jobs ]; then
        echo ""
        echo -e "${YELLOW}Waiting for jobs to complete...${NC}"
        wait -n
        job_count=$((job_count - 1))
    fi
    
    echo ""
done

# Wait for all remaining jobs
echo -e "${YELLOW}Waiting for all remaining simulations to complete...${NC}"
wait

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  All simulations completed!                           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Summary
echo -e "${GREEN}Results:${NC}"
for Re in "${REYNOLDS_NUMBERS[@]}"; do
    OUTPUT_DIR="Re_${Re}"
    if [ -f "$OUTPUT_DIR/drag_history.txt" ]; then
        n_lines=$(wc -l < "$OUTPUT_DIR/drag_history.txt")
        echo "  Re=$Re: $n_lines data points in drag_history.txt"
    else
        echo "  Re=$Re: simulation may have failed"
    fi
done

echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Monitor simulation:       tail -f Re_*/simulation.log"
echo "  2. View drag history:        cat Re_*/drag_history.txt"
echo "  3. Post-process results:     cd .. && python analyze_results.py"
echo "  4. Visualize in ParaView:    paraview Re_*/output-*.vtu"
