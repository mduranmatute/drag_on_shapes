#!/usr/bin/env python3
"""
Visualization script for Basilisk Stokes flow solver output.

Reads velocity field and grid configuration at mid-height plane (z=0)
and generates two plots:
1. Streamlines of velocity field
2. Grid configuration with refinement levels

Usage:
    python visualize_stokes.py [velocity_file] [grid_file] [output_dir]

Default files:
    velocity_field.txt  - Velocity field data (x, y, u_x, u_y)
    grid_config.txt     - Grid configuration (x_min, x_max, y_min, y_max, level, cs)
    ./                  - Output directory for PNG files
"""

import sys
import numpy as np
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import Rectangle, Circle
import warnings
warnings.filterwarnings('ignore')


def parse_metadata(filename):
    """Extract metadata from file header comments."""
    metadata = {}
    try:
        with open(filename, 'r') as f:
            for line in f:
                if line.startswith('# Domain:'):
                    # Extract L0, X0, Y0
                    parts = line.split('L0=')[1].split(',')
                    metadata['L0'] = float(parts[0])
                    metadata['X0'] = float(parts[1].split('X0=')[1])
                    metadata['Y0'] = float(parts[2].split('Y0=')[1])
                elif line.startswith('# Sphere:'):
                    # Extract diameter
                    parts = line.split('diameter=')[1].split(' ')
                    metadata['diameter'] = float(parts[0])
                elif not line.startswith('#'):
                    break
    except Exception as e:
        print(f"Warning: Could not parse metadata from {filename}: {e}")
    
    return metadata


def read_velocity_field(filename):
    """Read velocity field data from file."""
    print(f"Reading velocity field from {filename}...")
    
    data = []
    try:
        with open(filename, 'r') as f:
            for line in f:
                if line.startswith('#'):
                    continue
                parts = line.strip().split()
                if len(parts) >= 4:
                    try:
                        data.append([float(x) for x in parts[:4]])
                    except ValueError:
                        continue
    except FileNotFoundError:
        print(f"Error: {filename} not found")
        return None, None
    
    if not data:
        print("Error: No velocity data found")
        return None, None
    
    data = np.array(data)
    print(f"  Loaded {len(data)} velocity points")
    return data, parse_metadata(filename)


def read_grid_config(filename):
    """Read grid configuration data from file."""
    print(f"Reading grid configuration from {filename}...")
    
    data = []
    try:
        with open(filename, 'r') as f:
            for line in f:
                if line.startswith('#'):
                    continue
                parts = line.strip().split()
                if len(parts) >= 6:
                    try:
                        data.append([float(x) for x in parts[:6]])
                    except ValueError:
                        continue
    except FileNotFoundError:
        print(f"Error: {filename} not found")
        return None, None
    
    if not data:
        print("Error: No grid data found")
        return None, None
    
    data = np.array(data)
    print(f"  Loaded {len(data)} grid cells")
    return data, parse_metadata(filename)


def plot_streamlines(velocity_data, metadata, output_file):
    """Generate streamline plot of velocity field."""
    print("\nGenerating streamline plot...")
    
    # Extract coordinates and velocity
    x = velocity_data[:, 0]
    y = velocity_data[:, 1]
    u = velocity_data[:, 2]
    v = velocity_data[:, 3]
    
    # Create figure
    fig, ax = plt.subplots(figsize=(12, 10))
    
    # Create a scatter plot colored by velocity magnitude
    speed = np.sqrt(u**2 + v**2)
    scatter = ax.scatter(x, y, c=speed, s=20, cmap='viridis', alpha=0.6, edgecolors='none')
    
    # Overlay streamlines
    # Create a regular grid for streamline plotting
    x_min, x_max = x.min(), x.max()
    y_min, y_max = y.min(), y.max()
    
    # Create interpolation grid
    nx, ny = 30, 30
    x_grid = np.linspace(x_min, x_max, nx)
    y_grid = np.linspace(y_min, y_max, ny)
    X, Y = np.meshgrid(x_grid, y_grid)
    
    # Interpolate velocity onto grid using nearest neighbor
    from scipy.spatial import cKDTree
    tree = cKDTree(velocity_data[:, :2])
    distances, indices = tree.query(np.c_[X.ravel(), Y.ravel()], k=1)
    
    U = velocity_data[indices, 2].reshape(X.shape)
    V = velocity_data[indices, 3].reshape(X.shape)
    
    # Plot streamlines
    stream = ax.streamplot(X, Y, U, V, color='black', linewidth=0.5, density=1.5, arrowsize=1.5)
    
    # Add sphere boundary (if available)
    if 'diameter' in metadata:
        radius = metadata['diameter'] / 2.0
        circle = Circle((0, 0), radius, fill=False, edgecolor='red', linewidth=2, linestyle='--', label='Sphere')
        ax.add_patch(circle)
    
    # Add colorbar
    cbar = plt.colorbar(scatter, ax=ax, label='Velocity magnitude')
    
    # Labels and title
    ax.set_xlabel('x', fontsize=12)
    ax.set_ylabel('y', fontsize=12)
    ax.set_title('Velocity Streamlines at Mid-Height (z=0)', fontsize=14, fontweight='bold')
    ax.set_aspect('equal')
    ax.grid(True, alpha=0.3)
    ax.legend(loc='upper left', fontsize=10)
    
    # Save figure
    plt.tight_layout()
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    print(f"  Streamline plot saved to {output_file}")
    plt.close()


def plot_grid_config(grid_data, metadata, output_file):
    """Generate plot of grid configuration."""
    print("\nGenerating grid configuration plot...")
    
    # Extract grid information
    x_min = grid_data[:, 0]
    x_max = grid_data[:, 1]
    y_min = grid_data[:, 2]
    y_max = grid_data[:, 3]
    levels = grid_data[:, 4].astype(int)
    cs = grid_data[:, 5]  # Volume fractions (1=fluid, 0=solid)
    
    # Create figure
    fig, ax = plt.subplots(figsize=(12, 10))
    
    # Get color map based on refinement level
    level_min = levels.min()
    level_max = levels.max()
    cmap = plt.cm.get_cmap('RdYlGn_r')
    
    # Draw grid cells colored by refinement level
    for i in range(len(grid_data)):
        # Only draw fluid cells (cs > 0.5) for clarity
        if cs[i] > 0.5:
            # Normalize level to [0, 1] for color mapping
            color_val = (levels[i] - level_min) / (level_max - level_min + 1e-10)
            color = cmap(color_val)
            
            width = x_max[i] - x_min[i]
            height = y_max[i] - y_min[i]
            rect = Rectangle((x_min[i], y_min[i]), width, height, 
                           linewidth=0.3, edgecolor='black', facecolor=color, alpha=0.7)
            ax.add_patch(rect)
        else:
            # Draw partial cells (at boundary) in gray
            width = x_max[i] - x_min[i]
            height = y_max[i] - y_min[i]
            rect = Rectangle((x_min[i], y_min[i]), width, height,
                           linewidth=0.2, edgecolor='gray', facecolor='lightgray', alpha=0.5)
            ax.add_patch(rect)
    
    # Add sphere boundary (if available)
    if 'diameter' in metadata:
        radius = metadata['diameter'] / 2.0
        circle = Circle((0, 0), radius, fill=True, facecolor='red', alpha=0.3, 
                       edgecolor='darkred', linewidth=2, linestyle='--', label='Sphere')
        ax.add_patch(circle)
    
    # Set axis limits
    if 'X0' in metadata and 'Y0' in metadata and 'L0' in metadata:
        x_min_domain = metadata['X0']
        y_min_domain = metadata['Y0']
        L0 = metadata['L0']
        ax.set_xlim(x_min_domain, x_min_domain + L0)
        ax.set_ylim(y_min_domain, y_min_domain + L0)
    
    # Labels and title
    ax.set_xlabel('x', fontsize=12)
    ax.set_ylabel('y', fontsize=12)
    ax.set_title('Grid Configuration at Mid-Height (z=0)', fontsize=14, fontweight='bold')
    ax.set_aspect('equal')
    
    # Add colorbar for refinement levels
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=plt.Normalize(vmin=level_min, vmax=level_max))
    sm.set_array([])
    cbar = plt.colorbar(sm, ax=ax, label='Refinement Level')
    
    ax.legend(loc='upper left', fontsize=10)
    
    # Save figure
    plt.tight_layout()
    plt.savefig(output_file, dpi=150, bbox_inches='tight')
    print(f"  Grid configuration plot saved to {output_file}")
    plt.close()


def main():
    """Main function."""
    # Parse command line arguments
    if len(sys.argv) > 1:
        velocity_file = sys.argv[1]
    else:
        velocity_file = "velocity_field.txt"
    
    if len(sys.argv) > 2:
        grid_file = sys.argv[2]
    else:
        grid_file = "grid_config.txt"
    
    if len(sys.argv) > 3:
        output_dir = sys.argv[3]
    else:
        output_dir = "."
    
    print("=" * 60)
    print("Basilisk Stokes Flow Visualization")
    print("=" * 60)
    
    # Read data
    velocity_data, vel_metadata = read_velocity_field(velocity_file)
    if velocity_data is None:
        print("Failed to read velocity field")
        return 1
    
    grid_data, grid_metadata = read_grid_config(grid_file)
    if grid_data is None:
        print("Failed to read grid configuration")
        return 1
    
    # Use metadata from either file (should be the same)
    metadata = {**vel_metadata, **grid_metadata}
    
    print("\nMetadata:")
    for key, value in metadata.items():
        print(f"  {key}: {value}")
    
    # Generate plots
    streamline_file = f"{output_dir}/streamlines.png"
    grid_file_out = f"{output_dir}/grid_config.png"
    
    plot_streamlines(velocity_data, metadata, streamline_file)
    plot_grid_config(grid_data, metadata, grid_file_out)
    
    print("\n" + "=" * 60)
    print("Visualization complete!")
    print("=" * 60)
    print(f"\nOutput files:")
    print(f"  - {streamline_file}")
    print(f"  - {grid_file_out}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())
