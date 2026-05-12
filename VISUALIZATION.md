# Stokes Flow Visualization Guide

This guide explains how to generate and visualize simulation results from `stokes_improved.c`.

## Overview

The simulation now outputs two data files at the final time step:
1. **velocity_field.txt** - Velocity values at mid-height plane (z=0)
2. **grid_config.txt** - Grid configuration and refinement levels

The `visualize_stokes.py` script reads these files and generates two publication-quality PNG images.

## Quick Start

### 1. Run the simulation
```bash
# Compile with default parameters
./compile.sh improved serial

# Run (generates output files automatically)
./stokes_improved
```

This creates:
- `velocity_field.txt` - Velocity field data
- `grid_config.txt` - Grid configuration data
- `drag_history.txt` - Drag coefficient history
- `streamlines.png` - Visualization (after running script)
- `grid_config.png` - Visualization (after running script)

### 2. Generate visualizations
```bash
python3 visualize_stokes.py
```

This creates:
- `streamlines.png` - Velocity streamlines with magnitude coloring
- `grid_config.png` - Grid cells colored by refinement level

## Output Files

### velocity_field.txt
Tab-separated file with columns:
```
x             - x-coordinate
y             - y-coordinate  
u_x           - x-component of velocity
u_y           - y-component of velocity
```

Header contains metadata:
- Domain size (L0), origin (X0, Y0)
- Sphere diameter
- All points are at z ≈ 0 (mid-height)

### grid_config.txt
Tab-separated file with columns:
```
x_min, x_max  - Cell x-boundaries
y_min, y_max  - Cell y-boundaries
level         - Refinement level (higher = finer mesh)
cs            - Volume fraction (1.0 = fluid, 0.0 = solid)
```

Header contains metadata (same as velocity_field.txt).

## Visualization Script Options

### Basic usage
```bash
python3 visualize_stokes.py
```
Uses default filenames in current directory.

### Custom filenames and output directory
```bash
python3 visualize_stokes.py velocity_field.txt grid_config.txt ./output
```

Arguments:
1. `velocity_file` - Path to velocity data (default: velocity_field.txt)
2. `grid_file` - Path to grid configuration (default: grid_config.txt)
3. `output_dir` - Directory for PNG files (default: current directory)

## Generated Figures

### 1. Streamlines Plot (streamlines.png)
Shows velocity field as:
- **Background**: Scatter plot colored by velocity magnitude (viridis colormap)
- **Black lines**: Streamlines showing flow direction
- **Dashed red circle**: Sphere boundary
- **Colorbar**: Velocity magnitude scale

**Physical interpretation:**
- High velocity (yellow) far from sphere
- Low velocity (dark) near sphere due to no-slip condition
- Streamlines show how flow curves around the obstacle

### 2. Grid Configuration Plot (grid_config.png)
Shows mesh structure as:
- **Colored cells**: Fluid domain colored by refinement level (RdYlGn_r)
  - Red = coarse mesh (level 5)
  - Yellow = medium refinement (level 6)
  - Green = fine mesh (level 7+)
- **Light gray cells**: Partial cells at sphere boundary
- **Red shaded region**: Sphere interior
- **Black edges**: Cell boundaries

**Physical interpretation:**
- Mesh is refined near sphere (where gradients are high)
- Coarser mesh far from sphere (where flow is uniform)
- Different refinement levels visible in colored cells

## Requirements

Python 3 with packages:
```bash
pip install numpy matplotlib scipy
```

## Examples

### Example 1: Different Reynolds numbers
```bash
# Re = 0.01 (very viscous)
qcc -O2 -Wall -I/home/mduran/basilisk/src -DREYNOLDS=0.01 stokes_improved.c -o stokes_re001 -lm
./stokes_re001
python3 visualize_stokes.py

# Re = 1.0 (less viscous)
qcc -O2 -Wall -I/home/mduran/basilisk/src -DREYNOLDS=1.0 stokes_improved.c -o stokes_re1 -lm
./stokes_re1
python3 visualize_stokes.py
```

### Example 2: Different mesh refinement
```bash
# Coarse mesh
qcc -O2 -DLEVEL_MAX=5 stokes_improved.c -o stokes_coarse -lm
./stokes_coarse
python3 visualize_stokes.py  # Shows coarser grid

# Fine mesh
qcc -O2 -DLEVEL_MAX=8 stokes_improved.c -o stokes_fine -lm
./stokes_fine
python3 visualize_stokes.py  # Shows finer grid with more detail
```

## Troubleshooting

### "No data found" error
- Check that `velocity_field.txt` and `grid_config.txt` exist
- Run `./stokes_improved` first to generate them

### Incomplete or empty plots
- Ensure simulation reached steady state (check simulation time)
- Try longer simulation: `qcc -O2 -DMAX_TIME=100 stokes_improved.c -o stokes_long -lm`

### Can't import matplotlib
- Install: `pip install matplotlib scipy`

### Very coarse grid visualization
- Increase `LEVEL_MAX` at compile time: `qcc -O2 -DLEVEL_MAX=8 stokes_improved.c`

## File Format Details

### Metadata parsing
Lines starting with `#` are comments containing:
```
# Domain: L0=1.600000e+01, X0=-3.000000e+00, Y0=-8.000000e+00
# Sphere: diameter=1.000000e+00 at origin
```

Python script automatically extracts:
- `L0`: Domain size
- `X0, Y0`: Domain origin
- `diameter`: Sphere diameter

This allows plots to be self-contained and properly scaled.

## Notes

- All coordinates are in physical units (not normalized)
- Velocity components are in physical units
- Refinement levels are integers (5=coarse, 8=finest in current setup)
- Volume fractions (cs) are between 0 and 1
  - 1.0 = entirely in fluid
  - 0.0 = entirely in solid
  - 0.0-1.0 = partially in sphere (boundary cells)

## See Also

- `README.md` - Main project documentation
- `stokes_improved.c` - Source code with simulation parameters
- `compile.sh` - Build script with options for different configurations
