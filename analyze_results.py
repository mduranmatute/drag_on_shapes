#!/usr/bin/env python3
"""
Post-processing script for Stokes flow simulations.
Analyzes drag history and compares with theoretical predictions.
"""

import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import sys

def read_drag_history(filename):
    """Read drag history file."""
    try:
        data = np.loadtxt(filename, skiprows=1)
        if data.ndim == 1:
            data = data.reshape(1, -1)
        return data
    except FileNotFoundError:
        print(f"Error: File {filename} not found")
        return None

def stokes_drag_theory(mu, radius, velocity):
    """Calculate theoretical Stokes drag force."""
    return 6 * np.pi * mu * radius * velocity

def analyze_simulation(base_dir, re_number, domain_size=1.0):
    """Analyze a single simulation."""
    
    drag_file = Path(base_dir) / "drag_history.txt"
    
    if not drag_file.exists():
        print(f"Warning: No drag history found in {base_dir}")
        return None
    
    # Read data
    data = read_drag_history(drag_file)
    if data is None:
        return None
    
    time = data[:, 0]
    Fx = data[:, 1]
    Fy = data[:, 2]
    Fz = data[:, 3]
    F_mag = data[:, 4]
    Cd = data[:, 5]
    
    # Physical parameters
    rho = 1.0
    U_inlet = 1.0
    radius = domain_size / 4.0  # diameter = domain_size/2
    mu = rho * U_inlet * domain_size / re_number if re_number > 0 else np.inf
    
    # Theoretical values
    F_stokes = stokes_drag_theory(mu, radius, U_inlet)
    area = np.pi * radius**2
    Cd_stokes = 2 * F_stokes / (rho * U_inlet**2 * area)
    
    # Statistics (from last 20% of simulation for steady state)
    n_skip = int(0.2 * len(time))
    F_mean = np.mean(F_mag[n_skip:])
    F_std = np.std(F_mag[n_skip:])
    Cd_mean = np.mean(Cd[n_skip:])
    Cd_std = np.std(Cd[n_skip:])
    
    return {
        'time': time,
        'Fx': Fx,
        'Fy': Fy,
        'Fz': Fz,
        'F_mag': F_mag,
        'Cd': Cd,
        'F_mean': F_mean,
        'F_std': F_std,
        'Cd_mean': Cd_mean,
        'Cd_std': Cd_std,
        'F_stokes': F_stokes,
        'Cd_stokes': Cd_stokes,
        'mu': mu,
        'radius': radius,
    }

def plot_single_simulation(results, re_number, output_file=None):
    """Plot results for a single simulation."""
    
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    
    # Plot 1: Force vs time
    ax = axes[0, 0]
    ax.plot(results['time'], results['F_mag'], 'b-', linewidth=1, label='Computed')
    ax.axhline(results['F_stokes'], color='r', linestyle='--', linewidth=2, 
               label=f'Stokes Theory = {results["F_stokes"]:.4e}')
    ax.set_xlabel('Time')
    ax.set_ylabel('Drag Force Magnitude')
    ax.set_title(f'Drag Force History (Re = {re_number})')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # Plot 2: Drag coefficient vs time
    ax = axes[0, 1]
    ax.plot(results['time'], results['Cd'], 'g-', linewidth=1, label='Computed')
    ax.axhline(results['Cd_stokes'], color='r', linestyle='--', linewidth=2,
               label=f'Stokes Theory = {results["Cd_stokes"]:.4f}')
    ax.set_xlabel('Time')
    ax.set_ylabel('Drag Coefficient')
    ax.set_title(f'Drag Coefficient History (Re = {re_number})')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # Plot 3: Force components
    ax = axes[1, 0]
    ax.plot(results['time'], results['Fx'], label='Fx', linewidth=1)
    ax.plot(results['time'], results['Fy'], label='Fy', linewidth=1)
    ax.plot(results['time'], results['Fz'], label='Fz', linewidth=1)
    ax.set_xlabel('Time')
    ax.set_ylabel('Force Component')
    ax.set_title('Force Components vs Time')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # Plot 4: Summary statistics
    ax = axes[1, 1]
    ax.axis('off')
    
    stats_text = f"""
    Reynolds Number: {re_number}
    
    Mean Drag Force: {results['F_mean']:.4e} ± {results['F_std']:.4e}
    Stokes Theory: {results['F_stokes']:.4e}
    Error: {abs(results['F_mean'] - results['F_stokes'])/results['F_stokes']*100:.2f}%
    
    Mean Drag Coeff: {results['Cd_mean']:.4f} ± {results['Cd_std']:.4f}
    Stokes Theory: {results['Cd_stokes']:.4f}
    
    Viscosity: {results['mu']:.4e}
    Sphere Radius: {results['radius']:.4f}
    """
    
    ax.text(0.1, 0.5, stats_text, fontsize=11, family='monospace',
            verticalalignment='center', bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    plt.tight_layout()
    
    if output_file:
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        print(f"Saved plot to {output_file}")
    
    return fig

def plot_comparison(results_dict, output_file=None):
    """Plot comparison of multiple Reynolds numbers."""
    
    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    
    re_numbers = sorted(results_dict.keys())
    
    # Plot 1: Drag vs Reynolds
    ax = axes[0]
    for re in re_numbers:
        results = results_dict[re]
        n_skip = int(0.2 * len(results['time']))
        ax.plot(results['time'], results['F_mag'], label=f'Re={re}', linewidth=1.5, alpha=0.7)
    
    ax.set_xlabel('Time')
    ax.set_ylabel('Drag Force Magnitude')
    ax.set_title('Drag Force History - Multiple Reynolds Numbers')
    ax.legend()
    ax.grid(True, alpha=0.3)
    
    # Plot 2: Steady-state comparison
    ax = axes[1]
    
    re_list = []
    cd_computed = []
    cd_theory = []
    cd_error = []
    
    for re in re_numbers:
        results = results_dict[re]
        n_skip = int(0.2 * len(results['time']))
        
        re_list.append(re)
        cd_computed.append(np.mean(results['Cd'][n_skip:]))
        cd_theory.append(results['Cd_stokes'])
        cd_error.append(abs(np.mean(results['Cd'][n_skip:]) - results['Cd_stokes']) / results['Cd_stokes'] * 100)
    
    x = np.arange(len(re_list))
    width = 0.35
    
    bars1 = ax.bar(x - width/2, cd_computed, width, label='Computed', alpha=0.8)
    bars2 = ax.bar(x + width/2, cd_theory, width, label='Stokes Theory', alpha=0.8)
    
    ax.set_xlabel('Reynolds Number')
    ax.set_ylabel('Drag Coefficient')
    ax.set_title('Steady-State Drag Coefficient Comparison')
    ax.set_xticks(x)
    ax.set_xticklabels([f'Re={re}' for re in re_list])
    ax.legend()
    ax.grid(True, alpha=0.3, axis='y')
    
    # Add error labels
    for i, error in enumerate(cd_error):
        ax.text(i, max(cd_computed[i], cd_theory[i]) * 1.05, f'{error:.1f}%', 
                ha='center', fontsize=9)
    
    plt.tight_layout()
    
    if output_file:
        plt.savefig(output_file, dpi=300, bbox_inches='tight')
        print(f"Saved comparison plot to {output_file}")
    
    return fig

if __name__ == "__main__":
    
    # Analyze current directory
    results_dict = {}
    
    # Look for simulation directories
    for sim_dir in sorted(Path(".").glob("Re_*")):
        # Extract Re number from directory name
        re_str = sim_dir.name.split("_")[1]
        
        try:
            re_number = float(re_str)
            print(f"\nAnalyzing {sim_dir}...")
            
            results = analyze_simulation(sim_dir, re_number)
            if results:
                results_dict[re_number] = results
                print(f"  Computed Cd (mean): {results['Cd_mean']:.4f} ± {results['Cd_std']:.4f}")
                print(f"  Stokes Theory Cd:   {results['Cd_stokes']:.4f}")
                print(f"  Error: {abs(results['Cd_mean'] - results['Cd_stokes'])/results['Cd_stokes']*100:.2f}%")
                
                # Plot individual simulation
                plot_single_simulation(results, re_number, output_file=f"{sim_dir}/analysis.png")
        
        except ValueError:
            print(f"Warning: Could not parse Re number from {sim_dir}")
    
    # Plot comparison if multiple simulations
    if len(results_dict) > 1:
        print("\n" + "="*50)
        print("Generating comparison plot...")
        plot_comparison(results_dict, output_file="comparison.png")
    
    print("\nAnalysis complete!")
    plt.show()
