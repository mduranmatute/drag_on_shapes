#!/bin/bash

# Compilation script for minimal Basilisk Stokes flow solver
# Supports: Serial, OpenMP, and MPI compilation

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Defaults
COMPILER="qcc"
MODE="serial"
NUM_CORES=1
OPTIMIZATION="-O2"
EXTRA_FLAGS="-Wall"

# Parse arguments
if [ $# -eq 0 ]; then
    MODE="serial"
elif [ "$1" == "serial" ]; then
    MODE="serial"
elif [ "$1" == "openmp" ]; then
    MODE="openmp"
    NUM_CORES=${2:-10}
elif [ "$1" == "mpi" ]; then
    MODE="mpi"
    NUM_CORES=${2:-10}
    COMPILER="mpicc"
elif [ "$1" == "help" ] || [ "$1" == "-h" ]; then
    echo "Minimal Basilisk Stokes Flow Solver - Compilation"
    echo ""
    echo "Usage: $0 [mode] [args]"
    echo ""
    echo "Modes:"
    echo "  serial                  Serial execution (default)"
    echo "  openmp [n_cores]        OpenMP (default: 10 cores)"
    echo "  mpi [n_procs]           MPI (default: 10 processes)"
    echo ""
    echo "Examples:"
    echo "  $0 serial"
    echo "  $0 openmp 10"
    echo "  $0 mpi 4"
    echo ""
    exit 0
else
    echo -e "${RED}Unknown mode: $1${NC}"
    echo "Use '$0 help' for usage information"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Minimal Basilisk Stokes Flow Solver - Compilation    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check source file
if [ ! -f "stokes_sphere_minimal.c" ]; then
    echo -e "${RED}Error: stokes_sphere_minimal.c not found!${NC}"
    exit 1
fi

echo -e "${GREEN}Configuration:${NC}"
echo "  Mode: $MODE"
echo "  Compiler: $COMPILER"
echo "  Optimization: $OPTIMIZATION"

case $MODE in
    serial)
        echo "  Cores: 1 (serial execution)"
        OUTPUT_NAME="stokes_minimal"
        COMPILE_CMD="$COMPILER $OPTIMIZATION $EXTRA_FLAGS stokes_sphere_minimal.c -o $OUTPUT_NAME -lm"
        ;;
    
    openmp)
        echo "  Cores: $NUM_CORES (OpenMP)"
        OUTPUT_NAME="stokes_minimal_omp"
        COMPILE_CMD="$COMPILER $OPTIMIZATION $EXTRA_FLAGS stokes_sphere_minimal.c -o $OUTPUT_NAME -lm -fopenmp"
        ;;
    
    mpi)
        echo "  Processes: $NUM_CORES (MPI)"
        OUTPUT_NAME="stokes_minimal_mpi"
        COMPILE_CMD="$COMPILER $OPTIMIZATION $EXTRA_FLAGS stokes_sphere_minimal.c -o $OUTPUT_NAME -lm"
        
        # Check if mpicc exists
        if ! command -v mpicc &> /dev/null; then
            echo -e "${RED}Error: mpicc not found. Install OpenMPI or MPICH.${NC}"
            exit 1
        fi
        ;;
esac

echo ""
echo -e "${GREEN}Compilation command:${NC}"
echo "  $COMPILE_CMD"
echo ""

# Compile
echo -e "${BLUE}Compiling...${NC}"
if eval $COMPILE_CMD; then
    echo -e "${GREEN}✓ Compilation successful!${NC}"
    echo ""
    echo -e "${GREEN}Output executable:${NC} $OUTPUT_NAME"
    echo ""
    
    # Print execution instructions
    case $MODE in
        serial)
            echo -e "${GREEN}To run:${NC}"
            echo "  ./$OUTPUT_NAME"
            ;;
        
        openmp)
            echo -e "${GREEN}To run with $NUM_CORES cores:${NC}"
            echo "  export OMP_NUM_THREADS=$NUM_CORES"
            echo "  ./$OUTPUT_NAME"
            ;;
        
        mpi)
            echo -e "${GREEN}To run with $NUM_CORES processes:${NC}"
            echo "  mpirun -np $NUM_CORES ./$OUTPUT_NAME"
            ;;
    esac
    
    echo ""
    ls -lh $OUTPUT_NAME
else
    echo -e "${RED}✗ Compilation failed!${NC}"
    exit 1
fi
