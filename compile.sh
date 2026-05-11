#!/bin/bash

# Compilation script for Basilisk Stokes flow solvers
# Supports both minimal and improved implementations
# Supports: Serial, OpenMP, and MPI compilation

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Defaults
COMPILER="qcc"
VERSION="minimal"
MODE="serial"
NUM_CORES=1
OPTIMIZATION="-O2"
EXTRA_FLAGS="-Wall"

# Parse arguments
if [ $# -eq 0 ]; then
    VERSION="minimal"
    MODE="serial"
elif [ "$1" == "minimal" ] || [ "$1" == "improved" ]; then
    VERSION="$1"
    MODE=${2:-serial}
    if [ "$MODE" == "openmp" ]; then
        NUM_CORES=${3:-10}
    elif [ "$MODE" == "mpi" ]; then
        NUM_CORES=${3:-10}
        COMPILER="mpicc"
    elif [ "$MODE" != "serial" ]; then
        echo -e "${RED}Unknown mode: $MODE${NC}"
        echo "Use '$0 help' for usage information"
        exit 1
    fi
elif [ "$1" == "serial" ] || [ "$1" == "openmp" ] || [ "$1" == "mpi" ]; then
    MODE="$1"
    VERSION="minimal"
    NUM_CORES=${2:-10}
    if [ "$MODE" == "mpi" ]; then
        COMPILER="mpicc"
    fi
elif [ "$1" == "help" ] || [ "$1" == "-h" ]; then
    echo "Basilisk Stokes Flow Solver - Compilation Script"
    echo ""
    echo "Usage: $0 [version] [mode] [args]"
    echo ""
    echo "Versions:"
    echo "  minimal                 Minimal working version (default)"
    echo "  improved                Improved version with embed.h"
    echo ""
    echo "Modes:"
    echo "  serial                  Serial execution (default)"
    echo "  openmp [n_cores]        OpenMP (default: 10 cores)"
    echo "  mpi [n_procs]           MPI (default: 10 processes)"
    echo ""
    echo "Examples:"
    echo "  $0                                  # minimal serial"
    echo "  $0 minimal serial                   # explicit minimal serial"
    echo "  $0 minimal openmp 4                 # minimal with OpenMP 4 cores"
    echo "  $0 improved serial                  # improved serial"
    echo "  $0 improved mpi 4                   # improved with MPI 4 processes"
    echo "  $0 serial                           # minimal serial (backward compat)"
    echo ""
    exit 0
else
    echo -e "${RED}Unknown argument: $1${NC}"
    echo "Use '$0 help' for usage information"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
if [ "$VERSION" == "minimal" ]; then
    echo -e "${BLUE}║  Minimal Basilisk Stokes Flow Solver - Compilation    ║${NC}"
else
    echo -e "${BLUE}║  Improved Basilisk Stokes Flow Solver - Compilation   ║${NC}"
fi
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check source file
SOURCE_FILE="stokes_sphere_${VERSION}.c"
if [ ! -f "$SOURCE_FILE" ]; then
    echo -e "${RED}Error: $SOURCE_FILE not found!${NC}"
    exit 1
fi

echo -e "${GREEN}Configuration:${NC}"
echo "  Version: $VERSION"
echo "  Mode: $MODE"
echo "  Compiler: $COMPILER"
echo "  Optimization: $OPTIMIZATION"

case $MODE in
    serial)
        echo "  Cores: 1 (serial execution)"
        OUTPUT_NAME="stokes_${VERSION}"
        COMPILE_CMD="$COMPILER $OPTIMIZATION $EXTRA_FLAGS $SOURCE_FILE -o $OUTPUT_NAME -lm"
        ;;
    
    openmp)
        echo "  Cores: $NUM_CORES (OpenMP)"
        OUTPUT_NAME="stokes_${VERSION}_omp"
        COMPILE_CMD="$COMPILER $OPTIMIZATION $EXTRA_FLAGS $SOURCE_FILE -o $OUTPUT_NAME -lm -fopenmp"
        ;;
    
    mpi)
        echo "  Processes: $NUM_CORES (MPI)"
        OUTPUT_NAME="stokes_${VERSION}_mpi"
        COMPILE_CMD="$COMPILER $OPTIMIZATION $EXTRA_FLAGS $SOURCE_FILE -o $OUTPUT_NAME -lm"
        
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
