# Stokes Flow Around a Sphere - Basilisk Solver

This repository contains a Basilisk fluid dynamics solver for simulating creeping flow (Stokes limit) around a sphere at the center of a cubic domain.

## Overview

The code solves the incompressible Navier-Stokes equations in the Stokes limit (Re → 0) using the Basilisk framework. Key features include:

- **Tunable Reynolds number**: Easily modify the flow regime from creeping flow to moderate Reynolds numbers
- **Adaptive mesh refinement**: Automatic mesh refinement near the sphere surface and velocity gradients
- **Drag calculation**: Computes pressure and viscous drag forces on the sphere
- **Theoretical validation**: Results compare against analytical Stokes drag formula

## Geometry

- **Domain**: Cubic box with side length `L`
- **Sphere**: Centered at origin with radius `r = L/4` (diameter = `L/2`)
- **Mesh refinement**: Finer resolution near sphere surface

## Governing Equations

In the Stokes limit, the Navier-Stokes equations reduce to:

```
∇·u = 0                    (continuity)
0 = -∇p + μ∇²u             (momentum, inviscid terms negligible)
```

Where:
- `u`: Velocity vector
- `p`: Pressure
- `μ`: Dynamic viscosity

The Reynolds number is defined as:
```
Re = ρ*U*L/μ
```

Where `ρ` is density, `U` is characteristic velocity, and `L` is characteristic length.

## Boundary Conditions

- **Inlet (x = -L/2)**: Uniform flow `u = (U₀, 0, 0)`
- **Outlet (x = L/2)**: Zero-gradient (Neumann) conditions
- **Side walls**: Symmetry conditions (zero normal velocity)
- **Sphere surface**: No-slip condition `u = 0`

## Drag Force

The total drag force on the sphere is calculated by integrating the stress tensor over the sphere surface:

```
F = ∮_S (σ·n) dS
```

Where:
- `σ = -pI + τ` is the stress tensor
- `τ = μ(∇u + ∇u^T)` is the viscous stress
- `n` is the outward surface normal

The drag coefficient is defined as:
```
Cd = 2*F / (ρ*U₀²*A)
```

Where `A = π*r²` is the sphere cross-sectional area.

### Stokes Drag Theory

For flow in the Stokes limit, the analytical solution gives:
```
F_Stokes = 6π*μ*r*U₀
```

Where `r` is the sphere radius. This is known as Stokes drag and depends only on viscosity and velocity, not on density (Re-independent for very low Re).

## Compilation and Execution

### Prerequisites

- Basilisk installed and configured
- C compiler (gcc)
- Standard math library

### Compilation

```bash
# Standard compilation
qcc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm

# With specific parameters at compile time
qcc -O2 -Wall -DREYNOLDS=0.01 -DDOMAIN_SIZE=1.0 stokes_sphere.c -o stokes_sphere -lm
```

### Execution

```bash
# Default parameters
./stokes_sphere

# Run with output redirection
./stokes_sphere > simulation.log 2>&1

# Monitor progress in real-time
tail -f simulation.log
```

## Tunable Parameters

Parameters can be modified in two ways:

### 1. In the source code (stokes_sphere.c)

```c
#define DOMAIN_SIZE 1.0       // Domain side length
#define REYNOLDS 0.1          // Reynolds number
#define INLET_VEL 1.0         // Inlet flow velocity
#define LEVEL_MAX 9           // Maximum mesh refinement
#define LEVEL_MIN 4           // Minimum mesh refinement
#define MAX_TIME 100.0        // Maximum simulation time
#define CFL_NUMBER 0.5        // CFL stability criterion
```

### 2. Compile-time flags

```bash
qcc -O2 -DREYNOLDS=1.0 -DDOMAIN_SIZE=2.0 stokes_sphere.c -o stokes_sphere -lm
```

## Output Files

### 1. `drag_history.txt`

Tab-separated file containing drag force history:
```
# Time    F_x         F_y         F_z         F_mag       Cd
0.000000  -0.123456   0.000001    0.000001    0.123456    0.987654
...
```

### 2. `output-XXXXX.vtu`

VTU (VTK Unstructured) format files containing:
- Pressure field
- Velocity components (u_x, u_y, u_z)
- Velocity magnitude

Visualize with ParaView or VisIt:
```bash
paraview output-*.vtu
```

### 3. Console output

Real-time diagnostics printed to stderr including:
- Simulation parameters
- Iteration count, time, and max velocity
- Drag forces and coefficients
- Grid statistics

## Example Usage

### Low Reynolds number (Stokes limit)

```bash
qcc -O2 -DREYNOLDS=0.01 -DLEVEL_MAX=8 stokes_sphere.c -o stokes_sphere_Re0.01 -lm
./stokes_sphere_Re0.01 > stokes_Re0.01.log 2>&1
```

Expected: Drag coefficient close to Stokes theory value.

### Higher Reynolds number

```bash
qcc -O2 -DREYNOLDS=1.0 -DLEVEL_MAX=9 stokes_sphere.c -o stokes_sphere_Re1 -lm
./stokes_sphere_Re1 > stokes_Re1.log 2>&1
```

Expected: More vorticity in wake, slightly higher drag coefficient.

### Coarse mesh for quick test

```bash
qcc -O2 -DLEVEL_MAX=6 -DMAX_TIME=10 stokes_sphere.c -o stokes_sphere_quick -lm
./stokes_sphere_quick
```

## Physical Parameters

| Parameter | Default | Symbol | Description |
|-----------|---------|--------|-------------|
| Domain size | 1.0 | L | Side length of cubic domain |
| Sphere radius | 0.25 | r | Radius of sphere (L/4) |
| Reynolds number | 0.1 | Re | ρ*U*L/μ |
| Inlet velocity | 1.0 | U₀ | Flow velocity at inlet |
| Density | 1.0 | ρ | Fluid density |
| Dynamic viscosity | computed | μ | From Re = ρ*U*L/μ |

## Validation

For Stokes flow (Re << 1), compare computed drag against theory:
- **Theoretical**: F = 6π*μ*r*U₀
- **Numerical**: Integrate stress over sphere surface

Convergence can be tested by:
1. Refining the mesh (increase `LEVEL_MAX`)
2. Increasing domain size to reduce blockage effects
3. Checking mesh independence

## Mesh Refinement Details

- Adaptive mesh refinement based on velocity and pressure gradients
- `LEVEL_MIN`: Coarsest allowed refinement level (16³ cells at level 4)
- `LEVEL_MAX`: Finest allowed refinement level (512³ max cells at level 9)
- Refinement criterion: Wavelets with tolerance for u, v, w, p

The code uses an octree grid structure for efficient memory usage.

## Performance Considerations

- Simulation time depends strongly on `LEVEL_MAX` and domain size
- CFL number controls timestep: smaller CFL → smaller steps but more stable
- AMR reduces total cells compared to uniform grids
- For very high Re, finer meshes needed to resolve wake structures

## Troubleshooting

### Simulation diverges

- Reduce `CFL_NUMBER` (try 0.2 instead of 0.5)
- Increase `LEVEL_MAX` for better resolution
- Reduce `REYNOLDS` number to stay in Stokes regime

### Slow convergence

- Ensure mesh is sufficiently refined (`LEVEL_MAX ≥ 8`)
- Check that CFL condition is appropriate
- Verify boundary conditions are physical

### Memory issues

- Reduce `LEVEL_MAX` to coarsen mesh
- Reduce `DOMAIN_SIZE` if not needed
- Run on smaller Re (lower viscosity = smaller timesteps)

## References

- **Basilisk documentation**: http://basilisk.fr/
- **Stokes flow theory**: Batchelor, G.K. "An Introduction to Fluid Dynamics" (Cambridge, 1967)
- **Computational methods**: Pozrikidis, C. "Boundary Integral and Singularity Methods" (Cambridge, 1992)

## License

This code is provided as-is for research and educational purposes.

## Author Notes

This Basilisk solver implements creeping flow around a sphere using:
- Centered grid discretization for velocity and pressure
- Adaptive wavelet-based mesh refinement
- Implicit viscous terms for numerical stability
- Surface stress integration for force calculation

The code demonstrates key capabilities of Basilisk for solving classical fluid mechanics problems with automatic mesh adaptation.
