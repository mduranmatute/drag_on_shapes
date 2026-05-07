# Quick Start Guide

## 5-Minute Setup

### 1. Verify Basilisk Installation

```bash
which qcc
qcc --version
```

If not found, follow: http://basilisk.fr/

### 2. Compile the Default Case

```bash
qcc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm
```

### 3. Run Simulation

```bash
./stokes_sphere
```

You'll see output like:
```
=== STOKES FLOW AROUND SPHERE ===
Domain size: 1.0000
Sphere radius: 0.2500 (diameter: 0.5000)
Reynolds number: 1.0000e-01
Dynamic viscosity: 1.0000e+01
...
```

### 4. Monitor Progress

In another terminal:
```bash
tail -f drag_history.txt
```

### 5. Visualize Results

Once simulation completes:
```bash
paraview output-*.vtu &
```

## Common Parameter Changes

### Low Reynolds Number (Stokes Limit)
```bash
qcc -O2 -DREYNOLDS=0.001 stokes_sphere.c -o stokes_Re0.001 -lm
./stokes_Re0.001
```

### Higher Reynolds Number
```bash
qcc -O2 -DREYNOLDS=10 -DLEVEL_MAX=9 stokes_sphere.c -o stokes_Re10 -lm
./stokes_Re10
```

### Coarse Mesh (Quick Test)
```bash
qcc -O2 -DLEVEL_MAX=6 -DMAX_TIME=10 stokes_sphere.c -o stokes_quick -lm
./stokes_quick
```

### Large Domain (Reduce Blockage)
```bash
qcc -O2 -DDOMAIN_SIZE=2.0 stokes_sphere.c -o stokes_large -lm
./stokes_large
```

## Parameter Study

Run multiple Reynolds numbers:
```bash
./run_simulations.sh 0.01 0.1 1.0 10.0
```

Then analyze results:
```bash
cd simulations
python ../analyze_results.py
```

## Output Interpretation

### drag_history.txt

Column | Meaning
--------|--------
1 | Time
2-4 | Force components (Fx, Fy, Fz)
5 | Force magnitude
6 | Drag coefficient

For Stokes flow (Re << 1), the drag coefficient should be relatively constant.

### Expected Results

**Stokes Theory**: F = 6π·μ·r·U₀

For **Re = 0.1**:
- Domain size L = 1.0
- Sphere radius r = 0.25
- Inlet velocity U₀ = 1.0
- μ = ρ·U·L / Re = 1 × 1 × 1 / 0.1 = 10
- F_theory = 6π × 10 × 0.25 × 1 = **47.12**
- Cd_theory ≈ **1.51** (with blockage effects)

Numerical result should be within 5-10% of theory for adequate mesh refinement.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "qcc: command not found" | Install Basilisk or add to PATH |
| Simulation diverges | Reduce CFL_NUMBER or increase LEVEL_MAX |
| Very slow simulation | Reduce LEVEL_MAX or DOMAIN_SIZE |
| Memory error | Lower resolution or use smaller domain |
| Noisy drag output | Increase simulation time (MAX_TIME) for better averaging |

## Next Steps

- Modify boundary conditions (e.g., slip walls)
- Add temperature equations for thermal flow
- Implement different shapes (ellipsoid, cylinder)
- Study wake dynamics at higher Reynolds numbers
- Validate against experimental data

## References

- **Basilisk Documentation**: http://basilisk.fr/
- **Example Cases**: http://basilisk.fr/cases/
- **Theory**: Stokes, G. G. "On the Effect of the Internal Friction of Fluids on the Motion of Pendulums" (1851)
