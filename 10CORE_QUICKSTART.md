# Running Stokes Solver on 10 Cores - Quick Reference

## Three Simple Ways to Use 10 Cores

### Option 1: OpenMP (Recommended for Single Machine)

**Simplest method. No external dependencies beyond compiler.**

```bash
# One command to rule them all:
bash run_10core_simple.sh
```

Or manually:
```bash
qcc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm -fopenmp
export OMP_NUM_THREADS=10
./stokes_sphere
```

**Advantages:** Simple, fast, no MPI setup needed

---

### Option 2: MPI (For Clusters or Advanced Users)

**Requires OpenMPI or MPICH installed.**

```bash
bash run_10core_mpi.sh
```

Or manually:
```bash
mpicc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm
mpirun -np 10 ./stokes_sphere
```

**Advantages:** Scales to multiple machines, better for large problems

**To install MPI:**
```bash
# macOS
brew install open-mpi

# Ubuntu/Debian
sudo apt-get install libopenmpi-dev

# CentOS/RHEL
sudo yum install openmpi-devel
```

---

### Option 3: Hybrid OpenMP/MPI

**Best for clusters with multi-core nodes.**

```bash
bash run_10core_hybrid.sh
```

Or manually:
```bash
mpicc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm -fopenmp
export OMP_NUM_THREADS=2
mpirun -np 5 ./stokes_sphere
```

**Advantages:** Balances communication overhead and parallelism

---

## Quick Start - 30 Seconds

```bash
# 1. Compile
qcc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm -fopenmp

# 2. Run on 10 cores
export OMP_NUM_THREADS=10
./stokes_sphere

# Done! Results in drag_history.txt and output-*.vtu
```

---

## Verify Parallelization

After starting a simulation, check it's actually using 10 cores:

```bash
# In another terminal, check processes/threads
# macOS/Linux:
top -o %CPU          # Watch for high CPU usage
ps -eLf | grep stokes_sphere

# More detailed:
ps -p PID -o %cpu,%mem,cmd
```

You should see:
- **OpenMP**: Single process using ~800-1000% CPU (10 cores × 100%)
- **MPI**: 10 separate processes, total ~800-1000% CPU

---

## Using the Compilation Script

For more control, use the compilation script:

```bash
# OpenMP (10 cores)
./compile.sh openmp 10

# MPI (10 processes)  
./compile.sh mpi 10

# Hybrid (5 MPI × 2 OpenMP)
./compile.sh hybrid 5 2

# See help
./compile.sh help
```

---

## Parameter Studies on 10 Cores

Run multiple Reynolds numbers in parallel:

```bash
# OpenMP: Each simulation uses 10 cores
./run_simulations.sh 0.01 0.1 1.0 --cores 10 --mode openmp

# MPI: Distribute 10 cores across simulations
./run_simulations.sh 0.01 0.1 1.0 --cores 10 --mode mpi
```

---

## Expected Performance

On a 10-core machine:

| Method | Compilation | Speedup | Notes |
|--------|-------------|---------|-------|
| Serial | `qcc ... -lm` | 1.0x | Baseline |
| OpenMP | `qcc ... -lm -fopenmp` | ~8-9x | Best for single machine |
| MPI | `mpicc ... -lm` | ~9-10x | Good for clusters |
| Hybrid | `mpicc ... -lm -fopenmp` | ~9-10x | Best for multi-node |

---

## Troubleshooting

### "Compiler says undefined reference to omp_get_max_threads"

**Solution:** Add `-fopenmp` flag to compilation
```bash
qcc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm -fopenmp
```

### "mpirun: command not found"

**Solution:** Install OpenMPI
```bash
# macOS
brew install open-mpi

# Ubuntu
sudo apt-get install openmpi-bin libopenmpi-dev

# CentOS
sudo yum install openmpi openmpi-devel
```

### "Only using 1 thread despite OMP_NUM_THREADS=10"

**Solution:** Recompile with `-fopenmp`
```bash
qcc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm -fopenmp
```

### "Simulation runs but shows only 1 thread"

Check compilation flags:
```bash
# This will NOT use OpenMP:
qcc -O2 stokes_sphere.c -o stokes_sphere -lm

# This WILL use OpenMP:
qcc -O2 stokes_sphere.c -o stokes_sphere -lm -fopenmp
```

### "Memory error or system slow"

Try reducing mesh resolution:
```bash
qcc -O2 -DLEVEL_MAX=7 stokes_sphere.c -o stokes_sphere -lm -fopenmp
./stokes_sphere
```

---

## Performance Monitoring

### Real-time CPU usage

```bash
# macOS/Linux with watch command
watch -n 1 'top -bn1 | head -20'

# Alternative: monitor specific process
while true; do ps aux | grep stokes_sphere | grep -v grep; sleep 1; done
```

### Check OpenMP thread efficiency

```bash
# Set diagnostic OpenMP settings
export OMP_NUM_THREADS=10
export OMP_DISPLAY_ENV=true
export OMP_DISPLAY_AFFINITY=false
./stokes_sphere 2>&1 | head -50
```

### Monitor MPI communication

```bash
mpirun -np 10 -x OMPI_MCA_orte_base_report_bindings=1 ./stokes_sphere
```

---

## Advanced Usage

### Set CPU Affinity for Better Performance

```bash
# OpenMP with thread pinning
export OMP_NUM_THREADS=10
export OMP_PLACES=cores
export OMP_PROC_BIND=close
./stokes_sphere
```

### MPI with Process Binding

```bash
# Bind MPI processes to cores
mpirun -np 10 --bind-to core --map-by core ./stokes_sphere

# With detailed binding info
mpirun -np 10 --bind-to core -report-bindings ./stokes_sphere
```

### Profile Execution Time

```bash
# Time the complete run
time ./stokes_sphere

# Profile with GNU tools (if available)
gprof ./stokes_sphere stokes_sphere.prof | less
```

---

## File Reference

| File | Purpose |
|------|---------|
| `stokes_sphere.c` | Main solver code (supports OpenMP/MPI) |
| `stokes_sphere_parallel.c` | Alternative parallel version with explicit MPI |
| `compile.sh` | Smart compilation script for all modes |
| `run_simulations.sh` | Parallel parameter study script |
| `run_10core_simple.sh` | OpenMP example (recommended) |
| `run_10core_mpi.sh` | MPI example |
| `run_10core_hybrid.sh` | Hybrid OpenMP/MPI example |
| `PARALLEL_GUIDE.md` | Comprehensive parallel documentation |

---

## Next Steps

1. **Quick Start:** Run `bash run_10core_simple.sh`
2. **Check Results:** `tail drag_history.txt` (drag converges to constant value)
3. **Visualize:** `paraview output-*.vtu` (if ParaView installed)
4. **Parameter Study:** `./run_simulations.sh 0.01 0.1 1.0 --cores 10`
5. **Analyze:** `python analyze_results.py` (if Python installed)

---

## Performance Tips

✓ **Use OpenMP** for single 10-core machine (simplest)  
✓ **Use MPI** for clusters or distributed systems  
✓ **Set thread affinity** for consistent performance  
✓ **Use appropriate mesh refinement** for 10 cores (LEVEL_MAX=8-9)  
✓ **Monitor CPU usage** to ensure parallelization is active  
✓ **Profile first run** to identify bottlenecks  

---

## References

- Basilisk: http://basilisk.fr/
- OpenMP: https://www.openmp.org/
- OpenMPI: https://www.open-mpi.org/
- For full details: See `PARALLEL_GUIDE.md`
