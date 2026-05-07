#!/bin/bash

# Example script: Hybrid OpenMP/MPI execution
# 5 MPI processes × 2 OpenMP threads per process = 10 cores total

# Check if mpirun is available
if ! command -v mpirun &> /dev/null; then
    echo "Error: mpirun not found. Install OpenMPI or MPICH."
    exit 1
fi

echo "Compiling with hybrid OpenMP/MPI support..."
echo "  5 MPI processes × 2 OpenMP threads = 10 cores total"
mpicc -O2 -Wall stokes_sphere.c -o stokes_sphere_hybrid -lm -fopenmp

echo ""
echo "Running simulation with hybrid parallelism..."
export OMP_NUM_THREADS=2
mpirun -np 5 ./stokes_sphere_hybrid

echo ""
echo "Simulation complete!"
echo "Results saved to:"
echo "  - drag_history.txt"
echo "  - output-*.vtu (for visualization)"
