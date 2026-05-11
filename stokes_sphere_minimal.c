/**
 * Minimal Stokes Flow Around a Sphere - Basilisk
 * 
 * Solves the incompressible Navier-Stokes equations for creeping flow
 * (Stokes regime) around a sphere in a cubic domain.
 * 
 * Features:
 * - Low Reynolds number flow (Re << 1)
 * - Adaptive mesh refinement around sphere
 * - Drag force calculation
 * - Simple, working implementation
 * 
 * Compile and run:
 *   qcc -O2 -Wall stokes_sphere_minimal.c -o stokes_minimal -lm
 *   ./stokes_minimal
 * 
 * Modify simulation parameters at compile time:
 *   qcc -O2 -DREYNOLDS=0.01 stokes_sphere_minimal.c -o stokes_minimal -lm
 */

#include "navier-stokes/centered.h"

/**
 * Problem parameters - customize via compile-time defines
 */
#ifndef LEVEL_MAX
#define LEVEL_MAX 7           // Max refinement level
#endif

#ifndef REYNOLDS
#define REYNOLDS 0.1          // Reynolds number
#endif

#ifndef DOMAIN_SIZE
#define DOMAIN_SIZE 1.0       // Domain side length
#endif

#ifndef INLET_VEL
#define INLET_VEL 1.0         // Inlet flow velocity
#endif

#ifndef MAX_TIME
#define MAX_TIME 50.0         // Simulation time
#endif

/**
 * Global parameters
 */
double RADIUS;                // Sphere radius
double MU_VAL;                // Dynamic viscosity
double RHO_VAL = 1.0;         // Density
FILE *drag_file = NULL;

/**
 * Boundary conditions for centered Navier-Stokes solver
 * Note: These must be defined at module scope before main()
 */
u.n[left] = dirichlet(INLET_VEL);
u.n[right] = neumann(0);
u.t[top] = neumann(0);
u.t[bottom] = neumann(0);

p[left] = neumann(0);
p[right] = dirichlet(0);

/**
 * Main program entry point
 */
int main() {
  // Domain setup
  L0 = DOMAIN_SIZE;
  origin(-L0/2, -L0/2, -L0/2);
  
  // Initial grid resolution
  N = 1 << 5;
  
  // Physical parameters
  RADIUS = L0 / 4.0;  // Sphere radius = L0/4 (diameter = L0/2)
  
  // Calculate dynamic viscosity from Reynolds number
  // Re = rho * U * L / mu  =>  mu = rho * U * L / Re
  MU_VAL = RHO_VAL * INLET_VEL * DOMAIN_SIZE / REYNOLDS;
  
  // Set viscosity for the centered solver
  // mu is a face vector field that needs to be initialized
  mu[] = {MU_VAL, MU_VAL};
  
  // Run the simulation
  run();
  
  return 0;
}

/**
 * Initialization event - called at i=0
 * Refine mesh in the sphere region
 */
event init(i = 0) {
  // Local mesh refinement around the sphere
  refine(sq(x) + sq(y) + sq(z) < sq(L0/2) && level < LEVEL_MAX);
}

/**
 * Adaptive mesh refinement event
 * Called periodically to refine based on error estimates
 */
event adapt(i += 2) {
  // Refine based on velocity field gradients
#if dimension == 3
  adapt_wavelet({u.x, u.y, u.z, p},
                (double[]){0.01, 0.01, 0.01, 0.01},
                LEVEL_MAX);
#else
  adapt_wavelet({u.x, u.y, p},
                (double[]){0.01, 0.01, 0.01},
                LEVEL_MAX);
#endif
}

/**
 * Sphere boundary condition - no-slip condition
 * Applied every iteration to enforce zero velocity inside sphere
 */
event sphere_bc(i++) {
  foreach() {
    double r = sqrt(sq(x) + sq(y) + sq(z));
    
    // Set velocity to zero inside sphere (no-slip)
    if (r < RADIUS) {
      u.x[] = 0;
      u.y[] = 0;
      u.z[] = 0;
    }
  }
}

/**
 * Calculate drag force on sphere surface
 * Integrates pressure and viscous stresses on a spherical surface
 */
double calculate_drag() {
  double Fx = 0, Fy = 0, Fz = 0;
  double h = L0 / (1 << LEVEL_MAX);
  
  // Integrate stress on sphere surface
  foreach(reduction(+:Fx) reduction(+:Fy) reduction(+:Fz)) {
    double r_val = sqrt(sq(x) + sq(y) + sq(z));
    
    // Check if cell is near sphere surface (within 2 cell widths)
    if (r_val > 1e-10 && fabs(r_val - RADIUS) < 2.0*h) {
      // Outward surface normal
      double nx = x / r_val;
      double ny = y / r_val;
      double nz = z / r_val;
      
      // Approximate surface area element
      double dS = 6.0 * h * h;
      
      // Pressure stress: sigma_p = -p * n
      double Fp_x = -p[] * nx * dS;
      double Fp_y = -p[] * ny * dS;
      double Fp_z = -p[] * nz * dS;
      
      // Velocity gradients (central differences)
      double du_dx = (u.x[1,0,0] - u.x[-1,0,0]) / (2*h);
      double du_dy = (u.x[0,1,0] - u.x[0,-1,0]) / (2*h);
      double du_dz = (u.x[0,0,1] - u.x[0,0,-1]) / (2*h);
      
      double dv_dx = (u.y[1,0,0] - u.y[-1,0,0]) / (2*h);
      double dv_dy = (u.y[0,1,0] - u.y[0,-1,0]) / (2*h);
      double dv_dz = (u.y[0,0,1] - u.y[0,0,-1]) / (2*h);
      
      double dw_dx = (u.z[1,0,0] - u.z[-1,0,0]) / (2*h);
      double dw_dy = (u.z[0,1,0] - u.z[0,-1,0]) / (2*h);
      double dw_dz = (u.z[0,0,1] - u.z[0,0,-1]) / (2*h);
      
      // Viscous stress tensor: tau_ij = mu * (du_i/dx_j + du_j/dx_i)
      double tau_xx = MU_VAL * (2.0*du_dx);
      double tau_yy = MU_VAL * (2.0*dv_dy);
      double tau_zz = MU_VAL * (2.0*dw_dz);
      double tau_xy = MU_VAL * (du_dy + dv_dx);
      double tau_xz = MU_VAL * (du_dz + dw_dx);
      double tau_yz = MU_VAL * (dv_dz + dw_dy);
      
      // Viscous stress force: sigma_v · n
      double Fv_x = (tau_xx*nx + tau_xy*ny + tau_xz*nz) * dS;
      double Fv_y = (tau_xy*nx + tau_yy*ny + tau_yz*nz) * dS;
      double Fv_z = (tau_xz*nx + tau_yz*ny + tau_zz*nz) * dS;
      
      // Accumulate total force
      Fx += Fp_x + Fv_x;
      Fy += Fp_y + Fv_y;
      Fz += Fp_z + Fv_z;
    }
  }
  
  return sqrt(sq(Fx) + sq(Fy) + sq(Fz));
}

/**
 * Output event - compute and write drag force
 * Called periodically to calculate and record drag coefficient
 */
event output(i += 5) {
  // Initialize output file on first call
  if (i == 0) {
    if (pid() == 0) {
      drag_file = fopen("drag_history.txt", "w");
      fprintf(drag_file, "# Time\t\tDrag_Force\t\tDrag_Coeff\n");
      fflush(drag_file);
    }
  }
  
  // Calculate drag force
  double F_mag = calculate_drag();
  double A = M_PI * sq(RADIUS);
  double Cd = 2.0 * F_mag / (RHO_VAL * sq(INLET_VEL) * A + 1e-10);
  
  // Theoretical Stokes drag: F = 6*pi*mu*R*U
  double F_stokes = 6.0 * M_PI * MU_VAL * RADIUS * INLET_VEL;
  double Cd_stokes = 2.0 * F_stokes / (RHO_VAL * sq(INLET_VEL) * A);
  
  if (pid() == 0) {
    fprintf(stderr, "t=%.4f: F_mag=%.6e, Cd=%.6e, Cd_theory=%.6e (Re=%.2e)\n",
            t, F_mag, Cd, Cd_stokes, REYNOLDS);
    
    if (drag_file) {
      fprintf(drag_file, "%.6e\t%.6e\t%.6e\n", t, F_mag, Cd);
      fflush(drag_file);
    }
  }
}

/**
 * Diagnostics event - print simulation statistics
 */
event stats(i += 10) {
  if (pid() == 0) {
    fprintf(stderr, "i=%d, t=%.4f, dt=%.4e, umax=%.4e\n",
            i, t, dt, normf(u.x).max);
  }
}

/**
 * End simulation event
 * Called when simulation reaches specified end time
 */
event end(t = MAX_TIME) {
  if (pid() == 0) {
    fprintf(stderr, "\n=== Simulation Complete ===\n");
    fprintf(stderr, "Final time: t=%.4f\n", t);
    fprintf(stderr, "Total iterations: %d\n", i);
    
    if (drag_file) {
      fclose(drag_file);
      fprintf(stderr, "Drag results saved to: drag_history.txt\n");
    }
    
    fprintf(stderr, "\nTheoretical Stokes drag: F = 6*pi*mu*R*U\n");
    double F_theory = 6.0 * M_PI * MU_VAL * RADIUS * INLET_VEL;
    fprintf(stderr, "F_theory = %.6e\n\n", F_theory);
  }
}
