#!/bin/bash

# Quick example script: Run Stokes solver on 10 cores with OpenMP
# This is the simplest way to use all 10 cores

echo "Compiling with OpenMP support for 10 cores..."
qcc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm -fopenmp

echo "Running simulation on 10 cores..."
export OMP_NUM_THREADS=10
./stokes_sphere

echo ""
echo "Simulation complete!"
echo "Results saved to:"
echo "  - drag_history.txt"
echo "  - output-*.vtu (for visualization)"
