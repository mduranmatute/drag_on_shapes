# Parallel Execution Guide

## Overview

The Basilisk Stokes flow solver now supports both **OpenMP** (shared-memory) and **MPI** (distributed-memory) parallelization. This allows you to run simulations efficiently on 10 cores or more.

## Parallelization Methods

### 1. OpenMP (Shared-Memory Parallelization)

**Best for:** Single machine with multiple cores (8, 10, 16, 32+ cores)

#### Compilation

```bash
# Compile with OpenMP support
qcc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm -fopenmp
```

#### Execution on 10 Cores

```bash
# Set number of threads to 10
export OMP_NUM_THREADS=10

# Run the simulation
./stokes_sphere
```

#### Verify OpenMP is Working

```bash
# Check number of threads being used
OMP_NUM_THREADS=10 ./stokes_sphere 2>&1 | head -30
```

**Output should show:**
```
Parallel Configuration:
  OpenMP threads: 10
  MPI processes: 1 (disabled)
  Total compute cores available: 10
```

#### Advanced OpenMP Settings

```bash
# Set thread affinity for better performance
export OMP_NUM_THREADS=10
export OMP_PLACES=cores
export OMP_PROC_BIND=close
./stokes_sphere

# Use nested parallelism (advanced)
export OMP_NUM_THREADS=10
export OMP_NESTED=TRUE
./stokes_sphere
```

### 2. MPI (Distributed-Memory Parallelization)

**Best for:** Computing clusters or machines with OpenMPI/MPICH installed

#### Prerequisites

Check if MPI is installed:
```bash
which mpirun
mpicc --version
```

If not installed, install OpenMPI:
```bash
# macOS
brew install open-mpi

# Linux (Ubuntu/Debian)
sudo apt-get install libopenmpi-dev openmpi-bin

# Linux (CentOS/RHEL)
sudo yum install openmpi-devel
```

#### Compilation

```bash
# Compile with MPI support using mpicc
mpicc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm

# Or use qcc with MPI (if available in your Basilisk installation)
qcc -O2 -Wall -DUSE_MPI stokes_sphere.c -o stokes_sphere -lm
```

#### Execution on 10 Cores

```bash
# Run with 10 MPI processes
mpirun -np 10 ./stokes_sphere

# With additional options for local machine
mpirun -np 10 --bind-to core --map-by core ./stokes_sphere

# With verbose output
mpirun -np 10 -v ./stokes_sphere
```

#### MPI on Remote Cluster

```bash
# Create hostfile
cat > hostfile.txt << EOF
node1.cluster.com slots=10
EOF

# Run on cluster
mpirun -hostfile hostfile.txt -np 10 ./stokes_sphere

# Or using scheduler (e.g., SLURM)
sbatch -N 1 -n 10 run_mpi.sh
```

### 3. Hybrid OpenMP/MPI

**Best for:** Large clusters with multi-core nodes

```bash
# Compile with both OpenMP and MPI
mpicc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm -fopenmp
```

#### Execution (e.g., 5 MPI processes × 2 OpenMP threads = 10 cores)

```bash
export OMP_NUM_THREADS=2
mpirun -np 5 ./stokes_sphere
```

#### Execution (e.g., 2 MPI processes × 5 OpenMP threads = 10 cores)

```bash
export OMP_NUM_THREADS=5
mpirun -np 2 ./stokes_sphere
```

## Performance Comparison

### Timing Example

For a typical Stokes simulation with 10 cores:

```bash
# Create timing script
cat > time_run.sh << 'EOF'
#!/bin/bash
echo "Serial execution:"
time ./stokes_sphere_serial

echo ""
echo "OpenMP (10 threads):"
export OMP_NUM_THREADS=10
time ./stokes_sphere

echo ""
echo "MPI (10 processes):"
mpirun -np 10 time ./stokes_sphere
EOF

chmod +x time_run.sh
./time_run.sh
```

### Expected Speedup

- **OpenMP (10 threads)**: ~8-9x faster than serial (on 10 cores)
- **MPI (10 processes)**: ~9-10x faster than serial (with good network latency)
- **Hybrid**: Near-linear speedup up to physical core count

## Building Multi-Parameter Studies in Parallel

### 1. Serial Parameter Study with Parallel Execution

```bash
#!/bin/bash
# Run multiple Reynolds numbers in parallel

REYNOLDS_NUMBERS=(0.001 0.01 0.1 1.0 10.0)

for Re in "${REYNOLDS_NUMBERS[@]}"; do
    echo "Compiling for Re = $Re..."
    qcc -O2 -DREYNOLDS="$Re" -DLEVEL_MAX=8 stokes_sphere.c \
        -o "stokes_Re${Re}" -lm -fopenmp
    
    echo "Running for Re = $Re with 10 threads..."
    export OMP_NUM_THREADS=10
    ./stokes_Re${Re} > "log_Re${Re}.txt" 2>&1 &
done

wait
echo "All simulations completed!"
```

### 2. Updated run_simulations.sh for Parallel Execution

```bash
#!/bin/bash

# Script to run Stokes flow solver with different Reynolds numbers (PARALLEL)
# Usage: ./run_simulations.sh [Re1] [Re2] ... [num_cores]
# Example: ./run_simulations.sh 0.01 0.1 1.0 10

REYNOLDS_NUMBERS=("$@")
NUM_CORES=10  # Default

# Extract number of cores if provided as last argument
if [[ ${REYNOLDS_NUMBERS[-1]} =~ ^[0-9]+$ ]]; then
    NUM_CORES=${REYNOLDS_NUMBERS[-1]}
    unset 'REYNOLDS_NUMBERS[-1]'
fi

# Default Reynolds numbers if none provided
if [ ${#REYNOLDS_NUMBERS[@]} -eq 0 ]; then
    REYNOLDS_NUMBERS=(0.01 0.1 1.0)
fi

echo "Running parameter studies on $NUM_CORES cores..."
export OMP_NUM_THREADS=$NUM_CORES

mkdir -p simulations
cd simulations

for Re in "${REYNOLDS_NUMBERS[@]}"; do
    OUTPUT_DIR="Re_${Re}"
    mkdir -p "$OUTPUT_DIR"
    cd "$OUTPUT_DIR"
    
    cp ../../stokes_sphere.c .
    
    qcc -O2 -DREYNOLDS="$Re" -DLEVEL_MAX=8 stokes_sphere.c \
        -o stokes_sphere -lm -fopenmp
    
    ./stokes_sphere > simulation.log 2>&1
    
    cd ..
done

echo "All parameter studies completed!"
```

## Output Files

Output files are **automatically handled** by Basilisk in parallel:

```
drag_history.txt          # Single consolidated file (safe across MPI)
output-00001.vtu          # VTU files for visualization
output-00002.vtu
...
```

## Optimization Tips

### 1. Hardware Optimization

```bash
# Check CPU core count
nproc                    # Total cores
lscpu                    # Detailed CPU info

# Set optimal thread count
export OMP_NUM_THREADS=$(nproc)
```

### 2. Memory Optimization

```bash
# Reduce mesh resolution for faster convergence with more cores
qcc -O2 -DLEVEL_MAX=7 stokes_sphere.c -o stokes_sphere -lm -fopenmp

# Or increase domain size to better utilize cores
qcc -O2 -DDOMAIN_SIZE=2.0 stokes_sphere.c -o stokes_sphere -lm -fopenmp
```

### 3. Load Balancing

For Basilisk's adaptive mesh refinement:
- **OpenMP**: Automatic load balancing via work-stealing queue
- **MPI**: Automatic domain decomposition + load balancing

### 4. Monitoring Parallel Performance

```bash
# OpenMP: Monitor thread usage
export OMP_NUM_THREADS=10
./stokes_sphere 2>&1 | grep -i "parallel\|thread\|core"

# MPI: Monitor process communication
mpirun -np 10 ./stokes_sphere 2>&1 | head -50
```

## SLURM Job Submission (HPC Clusters)

### Example: 10 Cores on SLURM

```bash
#!/bin/bash
#SBATCH --job-name=stokes_flow
#SBATCH --nodes=1
#SBATCH --ntasks=10
#SBATCH --cpus-per-task=1
#SBATCH --time=01:00:00
#SBATCH --output=stokes_%j.log

module load openmpi
mpicc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm
mpirun -np 10 ./stokes_sphere
```

Submit job:
```bash
sbatch stokes_job.sh
```

### Example: Hybrid (5 MPI × 2 OpenMP = 10 cores)

```bash
#!/bin/bash
#SBATCH --job-name=stokes_hybrid
#SBATCH --nodes=1
#SBATCH --ntasks=5
#SBATCH --cpus-per-task=2
#SBATCH --time=01:00:00

module load openmpi
mpicc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm -fopenmp
export OMP_NUM_THREADS=2
mpirun -np 5 ./stokes_sphere
```

## Troubleshooting Parallel Execution

| Problem | Solution |
|---------|----------|
| "Number of threads = 1" | Add `-fopenmp` flag and verify `OMP_NUM_THREADS` is set |
| MPI compilation fails | Check if MPI is installed: `which mpicc` |
| Slow with many cores | May be I/O bound; reduce OUTPUT_FREQ in code |
| Memory error on cluster | Increase swap or reduce mesh resolution |
| Uneven performance | Check node load; use `top`, `htop`, or scheduler info |

## Verification

After running with 10 cores, check output:

```bash
# Check drag history exists
ls -lh drag_history.txt

# Verify convergence (should show steady drag values)
tail -20 drag_history.txt

# Check for any errors
grep -i error *.log
```

## Performance Benchmarking Script

```bash
#!/bin/bash
# benchmark_parallel.sh - Compare serial vs parallel performance

compile_serial() {
    qcc -O2 -Wall stokes_sphere.c -o stokes_serial -lm
}

compile_parallel() {
    qcc -O2 -Wall stokes_sphere.c -o stokes_omp -lm -fopenmp
    mpicc -O2 -Wall stokes_sphere.c -o stokes_mpi -lm
}

run_benchmark() {
    echo "=== BENCHMARK: Serial vs Parallel ==="
    
    echo "Serial (1 core)..."
    time ./stokes_serial > /dev/null 2>&1
    
    echo ""
    echo "OpenMP (10 cores)..."
    export OMP_NUM_THREADS=10
    time ./stokes_omp > /dev/null 2>&1
    
    echo ""
    echo "MPI (10 processes)..."
    time mpirun -np 10 ./stokes_mpi > /dev/null 2>&1
}

compile_serial
compile_parallel
run_benchmark
```

## References

- **OpenMP Specification**: https://www.openmp.org/
- **OpenMPI Documentation**: https://www.open-mpi.org/doc/
- **Basilisk Parallel Computing**: http://basilisk.fr/src/parallel.h
- **SLURM Documentation**: https://slurm.schedmd.com/

## Next Steps

1. Verify parallel execution: `OMP_NUM_THREADS=10 ./stokes_sphere`
2. Run parameter study: `./run_simulations.sh 0.01 0.1 1.0 10`
3. Monitor performance: Check wall-clock time reduction
4. Analyze results: `python analyze_results.py`
