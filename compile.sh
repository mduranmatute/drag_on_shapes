#!/bin/bash

# Compilation script for Basilisk Stokes flow solver with parallel support
# Supports: Serial, OpenMP, and MPI compilation
# 
# Usage:
#   ./compile.sh serial              # Serial compilation
#   ./compile.sh openmp 10           # OpenMP with 10 threads
#   ./compile.sh mpi 10              # MPI with 10 processes
#   ./compile.sh hybrid 5 2          # Hybrid: 5 MPI × 2 OpenMP threads

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Default options
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
elif [ "$1" == "hybrid" ]; then
    MODE="hybrid"
    MPI_PROCS=${2:-5}
    OMP_THREADS=${3:-2}
    NUM_CORES=$((MPI_PROCS * OMP_THREADS))
    COMPILER="mpicc"
elif [ "$1" == "help" ] || [ "$1" == "-h" ]; then
    echo "Compilation script for Basilisk Stokes flow solver"
    echo ""
    echo "Usage: $0 [mode] [args]"
    echo ""
    echo "Modes:"
    echo "  serial                  Serial execution (default)"
    echo "  openmp [n_cores]        OpenMP parallelization (default: 10 cores)"
    echo "  mpi [n_procs]           MPI parallelization (default: 10 processes)"
    echo "  hybrid [n_mpi] [n_omp]  Hybrid OpenMP/MPI (default: 5 MPI × 2 OMP)"
    echo ""
    echo "Examples:"
    echo "  $0 serial"
    echo "  $0 openmp 10"
    echo "  $0 mpi 10"
    echo "  $0 hybrid 5 2"
    echo ""
    exit 0
else
    echo -e "${RED}Unknown mode: $1${NC}"
    echo "Use '$0 help' for usage information"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Basilisk Stokes Flow Solver - Compilation Script     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verify source files exist
if [ ! -f "stokes_sphere.c" ]; then
    echo -e "${RED}Error: stokes_sphere.c not found!${NC}"
    exit 1
fi

echo -e "${GREEN}Configuration:${NC}"
echo "  Mode: $MODE"
echo "  Compiler: $COMPILER"
echo "  Optimization: $OPTIMIZATION"

case $MODE in
    serial)
        echo "  Cores: 1 (serial execution)"
        OUTPUT_NAME="stokes_sphere"
        COMPILE_CMD="$COMPILER $OPTIMIZATION $EXTRA_FLAGS stokes_sphere.c -o $OUTPUT_NAME -lm"
        ;;
    
    openmp)
        echo "  Cores: $NUM_CORES (OpenMP)"
        OUTPUT_NAME="stokes_sphere_omp"
        COMPILE_CMD="$COMPILER $OPTIMIZATION $EXTRA_FLAGS stokes_sphere.c -o $OUTPUT_NAME -lm -fopenmp"
        ;;
    
    mpi)
        echo "  Processes: $NUM_CORES (MPI)"
        OUTPUT_NAME="stokes_sphere_mpi"
        COMPILE_CMD="$COMPILER $OPTIMIZATION $EXTRA_FLAGS stokes_sphere.c -o $OUTPUT_NAME -lm"
        
        # Check if mpicc exists
        if ! command -v mpicc &> /dev/null; then
            echo -e "${RED}Error: mpicc not found. Install OpenMPI or MPICH.${NC}"
            exit 1
        fi
        ;;
    
    hybrid)
        echo "  Processes: $MPI_PROCS MPI × $OMP_THREADS OpenMP threads = $NUM_CORES total"
        OUTPUT_NAME="stokes_sphere_hybrid"
        COMPILE_CMD="$COMPILER $OPTIMIZATION $EXTRA_FLAGS stokes_sphere.c -o $OUTPUT_NAME -lm -fopenmp"
        
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
            echo ""
            echo -e "${GREEN}Advanced OpenMP settings:${NC}"
            echo "  export OMP_PLACES=cores"
            echo "  export OMP_PROC_BIND=close"
            ;;
        
        mpi)
            echo -e "${GREEN}To run with $NUM_CORES processes:${NC}"
            echo "  mpirun -np $NUM_CORES ./$OUTPUT_NAME"
            echo ""
            echo -e "${GREEN}With thread pinning:${NC}"
            echo "  mpirun -np $NUM_CORES --bind-to core --map-by core ./$OUTPUT_NAME"
            ;;
        
        hybrid)
            echo -e "${GREEN}To run with $MPI_PROCS MPI processes × $OMP_THREADS OpenMP threads:${NC}"
            echo "  export OMP_NUM_THREADS=$OMP_THREADS"
            echo "  mpirun -np $MPI_PROCS ./$OUTPUT_NAME"
            ;;
    esac
    
    echo ""
    ls -lh $OUTPUT_NAME
else
    echo -e "${RED}✗ Compilation failed!${NC}"
    exit 1
fi
