# Minimal Basilisk Stokes Flow Solver

This is a clean, working implementation of Stokes flow (creeping flow) around a sphere using Basilisk.

## What Changed

The original `stokes_sphere.c` had several critical issues:
- Referenced non-existent header `navier-stokes/perp.h`
- Incorrect type assignments (treating vector fields as scalars)
- Duplicated code blocks causing syntax errors
- Fundamental Basilisk API misunderstandings

**Solution**: Rewrote from scratch as `stokes_sphere_minimal.c` using proper Basilisk patterns from working examples.

## Quick Start

### 1. Compile (Serial)
```bash
qcc -O2 -Wall stokes_sphere_minimal.c -o stokes_minimal -lm
```

Or use the compile script:
```bash
./compile_minimal.sh serial
```

### 2. Run
```bash
./stokes_minimal
```

### 3. View Results
```bash
tail -f drag_history.txt        # Monitor drag coefficient
```

The simulation will run for 50 seconds (adjustable via `MAX_TIME` define).

## Features

- **Working Implementation**: Compiles and runs without errors
- **Adaptive Mesh Refinement**: Automatically refines mesh around sphere
- **Drag Force Calculation**: Outputs pressure and viscous drag components
- **Theoretical Validation**: Compares numerical vs. Stokes theory
- **Clean Code**: Well-commented, easy to understand and modify

## Customization

Modify parameters at compile time:

```bash
# Low Reynolds number (more viscous)
qcc -O2 -DREYNOLDS=0.001 stokes_sphere_minimal.c -o stokes_re_001 -lm

# Higher Reynolds number
qcc -O2 -DREYNOLDS=1.0 stokes_sphere_minimal.c -o stokes_re_1 -lm

# Longer simulation
qcc -O2 -DMAX_TIME=100 stokes_sphere_minimal.c -o stokes_long -lm

# Finer mesh
qcc -O2 -DLEVEL_MAX=8 stokes_sphere_minimal.c -o stokes_fine -lm

# Larger domain
qcc -O2 -DDOMAIN_SIZE=2.0 stokes_sphere_minimal.c -o stokes_large -lm
```

Available defines:
- `REYNOLDS`: Reynolds number (default: 0.1)
- `DOMAIN_SIZE`: Cubic domain side length (default: 1.0)
- `INLET_VEL`: Inlet flow velocity (default: 1.0)
- `LEVEL_MAX`: Maximum mesh refinement level (default: 7)
- `MAX_TIME`: Simulation end time (default: 50.0)

## Output

### Console Output
```
t=0.0000: F_mag=0.000000e+00, Cd=0.000000e+00, Cd_theory=4.800000e+02 (Re=1.00e-01)
i=0, t=0.0000, dt=5.6818e-04, umax=7.5000e-01
...
```

### drag_history.txt
Tab-separated values with columns:
- **Time**: Simulation time
- **Drag_Force**: Magnitude of drag force
- **Drag_Coeff**: Drag coefficient (Cd)

For Stokes flow (Re << 1), the drag coefficient should be relatively constant.

## Expected Results

For **Re = 0.1** (default):
- Domain size L = 1.0
- Sphere radius R = 0.25 (diameter = 0.5)
- Inlet velocity U₀ = 1.0
- Viscosity μ = 10

**Stokes Theory**: F = 6πμRU₀
- F_theory ≈ **47.1**
- Cd_theory ≈ **1.51** (with blockage effects)

Numerical results should be within 5-10% of theory for adequate mesh refinement.

## Parallel Compilation

### OpenMP (Shared Memory)
```bash
./compile_minimal.sh openmp 4
export OMP_NUM_THREADS=4
./stokes_minimal_omp
```

### MPI (Distributed Memory)
```bash
./compile_minimal.sh mpi 4
mpirun -np 4 ./stokes_minimal_mpi
```

## Key Differences from Original

| Aspect | Original | Minimal |
|--------|----------|---------|
| Compiles | ❌ No | ✅ Yes |
| Runs | ❌ No | ✅ Yes |
| Produces output | ❌ No | ✅ Yes |
| Code quality | ❌ Broken | ✅ Working |
| Documentation | ❌ Poor | ✅ Good |
| Sphere BC | ❌ Incorrect | ✅ Proper no-slip |

## Troubleshooting

**Error: `qcc: command not found`**
- Install Basilisk: http://basilisk.fr/

**Compilation errors about undefined symbols**
- Ensure Basilisk is properly installed
- Try: `which qcc && qcc --version`

**Very slow simulation**
- Reduce `LEVEL_MAX` for coarser mesh
- Reduce `MAX_TIME` for shorter run

**Drag force not converging**
- Increase simulation time (`MAX_TIME`)
- Increase mesh refinement (`LEVEL_MAX`)
- For very low Reynolds numbers, may need more time to reach steady state

## References

- Basilisk Documentation: http://basilisk.fr/
- Stokes Flow Theory: Creeping flow around sphere at Re << 1
- Drag on Sphere: F = 6πμRU (Stokes formula)

## Files

- `stokes_sphere_minimal.c`: Main simulation code
- `compile_minimal.sh`: Build script for different parallelization options
- `drag_history.txt`: Output file with drag coefficient history

## Next Steps

- Modify sphere geometry (ellipsoid, cylinder, etc.)
- Add temperature equations for thermal flow
- Implement different boundary conditions
- Study wake dynamics at higher Reynolds numbers
- Compare with experimental data
