#!/bin/bash

# Example script: Run Stokes solver on 10 cores with MPI
# Requires OpenMPI or MPICH to be installed

# Check if mpirun is available
if ! command -v mpirun &> /dev/null; then
    echo "Error: mpirun not found. Install OpenMPI or MPICH."
    echo "macOS: brew install open-mpi"
    echo "Linux: sudo apt-get install libopenmpi-dev openmpi-bin"
    exit 1
fi

echo "Compiling with MPI support for 10 processes..."
mpicc -O2 -Wall stokes_sphere.c -o stokes_sphere_mpi -lm

echo "Running simulation on 10 MPI processes..."
mpirun -np 10 ./stokes_sphere_mpi

echo ""
echo "Simulation complete!"
echo "Results saved to:"
echo "  - drag_history.txt"
echo "  - output-*.vtu (for visualization)"
