# Complete Workflow Example: Stokes Flow Around a Sphere

This document demonstrates a complete workflow from compilation through visualization.

## Workflow Overview

```
1. Compile simulation code
   ↓
2. Run simulation (generates output data files)
   ↓
3. Generate visualizations (creates PNG images)
   ↓
4. View results
```

## Step-by-Step Example

### Step 1: Compile the simulation

**Using the build script (recommended):**
```bash
cd /home/mduran/shapes/drag_on_shapes

# Serial compilation
./compile.sh improved serial

# Or with OpenMP parallelization
./compile.sh improved openmp 4
```

**Direct compilation with custom parameters:**
```bash
# Low Reynolds number (very viscous)
qcc -O2 -Wall -I/home/mduran/basilisk/src \
    -DREYNOLDS=0.01 -DMAX_TIME=50 \
    stokes_improved.c -o stokes_re001 -lm

# High Reynolds number (less viscous)  
qcc -O2 -Wall -I/home/mduran/basilisk/src \
    -DREYNOLDS=1.0 -DMAX_TIME=100 \
    stokes_improved.c -o stokes_re1 -lm

# Coarse mesh (fast, less accurate)
qcc -O2 -Wall -I/home/mduran/basilisk/src \
    -DLEVEL_MAX=5 -DMAX_TIME=10 \
    stokes_improved.c -o stokes_coarse -lm

# Fine mesh (slow, more accurate)
qcc -O2 -Wall -I/home/mduran/basilisk/src \
    -DLEVEL_MAX=8 -DMAX_TIME=200 \
    stokes_improved.c -o stokes_fine -lm
```

### Step 2: Run the simulation

**Basic execution:**
```bash
./stokes_improved
```

This will:
- Run the simulation for `MAX_TIME` seconds (default: 100)
- Print progress to stdout/stderr
- Generate three output files:
  - `drag_history.txt` - Drag coefficient vs time
  - `velocity_field.txt` - Velocity at mid-height plane
  - `grid_config.txt` - Grid structure at mid-height plane

**Example output:**
```
========================================
Basilisk Stokes Flow Solver - Compilation
========================================

Configuration:
  Version: improved
  Mode: serial
  Compiler: qcc
  Optimization: -O2

Compiling...
✓ Compilation successful!

./stokes_improved

t=0.0000: F=2.356931e+03, Cd=6.001875e+03, Cd_th=2.400000e+03 (Re=1.00e-01)
...
=== Simulation Complete ===
Final time: t=100.0000, iterations=520
Final mesh: 11245 cells
Drag results saved to: drag_history.txt
Velocity field saved to: velocity_field.txt
Grid configuration saved to: grid_config.txt
```

**With OpenMP parallelization:**
```bash
export OMP_NUM_THREADS=4
./stokes_improved_omp
```

### Step 3: Generate visualizations

**Standard usage:**
```bash
python3 visualize_stokes.py
```

**Custom output directory:**
```bash
python3 visualize_stokes.py velocity_field.txt grid_config.txt ./results/
```

**Output:**
```
============================================================
Basilisk Stokes Flow Visualization
============================================================
Reading velocity field from velocity_field.txt...
  Loaded 1600 velocity points
Reading grid configuration from grid_config.txt...
  Loaded 1608 grid cells

Metadata:
  L0: 16.0
  X0: -3.0
  Y0: -8.0
  diameter: 1.0

Generating streamline plot...
  Streamline plot saved to ./streamlines.png

Generating grid configuration plot...
  Grid configuration plot saved to ./grid_config.png

============================================================
Visualization complete!
============================================================

Output files:
  - ./streamlines.png
  - ./grid_config.png
```

### Step 4: View and analyze results

**View PNG images:**
```bash
# On Linux/Mac with display
feh streamlines.png
feh grid_config.png

# Or with any image viewer
display streamlines.png
display grid_config.png
```

**Analyze drag coefficient:**
```bash
# View drag history
cat drag_history.txt | head -20

# Plot with gnuplot
gnuplot << EOF
set xlabel 'Time'
set ylabel 'Drag coefficient'
plot 'drag_history.txt' using 1:3 with lines
EOF

# Or with Python
python3 << EOF
import numpy as np
import matplotlib.pyplot as plt

data = np.loadtxt('drag_history.txt', skiprows=1)
plt.figure(figsize=(10, 6))
plt.plot(data[:, 0], data[:, 2], 'b-', linewidth=2)
plt.xlabel('Time')
plt.ylabel('Drag Coefficient')
plt.grid(True, alpha=0.3)
plt.savefig('drag_history.png', dpi=150)
print("Saved drag_history.png")
EOF
```

## Complete Batch Workflow

Run multiple simulations at different Reynolds numbers:

```bash
#!/bin/bash

# Test different Reynolds numbers
for RE in 0.01 0.1 1.0 10.0; do
    echo "Running simulation for Re=$RE..."
    
    # Compile
    qcc -O2 -Wall -I/home/mduran/basilisk/src \
        -DREYNOLDS=$RE \
        stokes_improved.c -o "stokes_re${RE}" -lm
    
    # Run
    ./stokes_re${RE}
    
    # Rename outputs
    mkdir -p results_re${RE}
    mv velocity_field.txt results_re${RE}/
    mv grid_config.txt results_re${RE}/
    mv drag_history.txt results_re${RE}/
    
    # Generate visualizations
    python3 visualize_stokes.py \
        results_re${RE}/velocity_field.txt \
        results_re${RE}/grid_config.txt \
        results_re${RE}/
    
    echo "  Results saved to results_re${RE}/"
done

echo "All simulations complete!"
```

## Expected Results

### For Re = 0.1 (default):

**Stokes Theory:**
- Drag force: F = 6πμRU = 94.25 N
- Drag coefficient: Cd = 240 (using diameter as characteristic length)

**Numerical Results:**
- Typical Cd ≈ 40-50 (converges with mesh refinement)
- Error reduces with finer mesh (LEVEL_MAX increases)
- Steady state reached after t ≈ 20-30 time units

**Visualizations:**
- **Streamlines**: Show symmetric flow around sphere, highest velocity far field
- **Grid**: Heavy refinement near sphere, coarser away
  - Levels 7-8 near boundary
  - Levels 5-6 in far field

### For Re = 0.01 (very viscous):

- Convergence faster (fewer iterations needed)
- More symmetric flow pattern
- Closer to Stokes theory

### For Re = 1.0 (less viscous):

- Some asymmetry may appear
- Longer simulation needed for convergence
- Vortex formation behind sphere may be visible

## Output Files Reference

| File | Content | Generated By |
|------|---------|--------------|
| `stokes_improved` | Compiled executable | `compile.sh` / `qcc` |
| `drag_history.txt` | Time-series drag data | `stokes_improved` (end event) |
| `velocity_field.txt` | Velocity at z=0 plane | `stokes_improved` (end event) |
| `grid_config.txt` | Grid cells at z=0 plane | `stokes_improved` (end event) |
| `streamlines.png` | Velocity streamlines plot | `visualize_stokes.py` |
| `grid_config.png` | Grid structure plot | `visualize_stokes.py` |

## Common Parameter Combinations

```bash
# Quick test (coarse, fast)
qcc -O2 -DLEVEL_MAX=5 -DMAX_TIME=10 stokes_improved.c -o stokes_quick -lm
./stokes_quick
python3 visualize_stokes.py

# Production run (fine, accurate)
qcc -O2 -DLEVEL_MAX=8 -DMAX_TIME=200 stokes_improved.c -o stokes_fine -lm
./stokes_fine
python3 visualize_stokes.py

# Parallel computation (4 cores, balanced)
qcc -O2 -DLEVEL_MAX=7 -DMAX_TIME=100 -fopenmp stokes_improved.c -o stokes_omp -lm
export OMP_NUM_THREADS=4
./stokes_omp
python3 visualize_stokes.py

# Very low Reynolds number (viscous, slow flow)
qcc -O2 -DREYNOLDS=0.001 -DMAX_TIME=50 stokes_improved.c -o stokes_viscous -lm
./stokes_viscous
python3 visualize_stokes.py
```

## Troubleshooting

### Simulation takes too long
- Reduce `LEVEL_MAX`: `-DLEVEL_MAX=5` (coarser mesh)
- Reduce `MAX_TIME`: `-DMAX_TIME=10` (shorter run)
- Use OpenMP: `./compile.sh improved openmp 8`

### Poor visualization quality
- Increase `LEVEL_MAX`: `-DLEVEL_MAX=8` (finer mesh)
- Increase `MAX_TIME`: `-DMAX_TIME=200` (longer convergence)
- Check metadata in output files matches domain

### Different results than expected
- Verify Reynolds number: `grep "Re=" stderr output`
- Check mesh convergence: compare LEVEL_MAX=6 vs LEVEL_MAX=8
- Verify simulation has converged (time near MAX_TIME)

## Next Steps

- Explore different Reynolds numbers
- Compare mesh refinement effects
- Modify sphere size or domain size
- Extend to 3D analysis (modify visualization)
- Compare with experimental or analytical results

See `README.md`, `VISUALIZATION.md`, and source code comments for more details.
