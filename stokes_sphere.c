/**
 * Stokes Flow Around a Sphere - Basilisk Simulation
 * 
 * Solves the incompressible Navier-Stokes equations in the Stokes limit (creeping flow)
 * for flow around a sphere centered in a cubic domain.
 * 
 * PARALLEL SUPPORT:
 * - OpenMP: Shared-memory parallelization for multi-core systems
 * - MPI: Distributed-memory parallelization for clusters
 * 
 * Features:
 * - Tunable Reynolds number
 * - Sphere diameter = domain size / 2
 * - Adaptive mesh refinement around sphere
 * - Drag force calculation
 * - Automatic parallelization across cores/processors
 * 
 * Compile and run:
 * 
 * Serial:
 *   qcc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm
 *   ./stokes_sphere
 * 
 * OpenMP (10 cores):
 *   qcc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm -fopenmp
 *   OMP_NUM_THREADS=10 ./stokes_sphere
 * 
 * MPI (10 processes):
 *   mpicc -O2 -Wall stokes_sphere.c -o stokes_sphere -lm
 *   mpirun -np 10 ./stokes_sphere
 */

#include "grid/octree.h"
#include "embed.h"
#include "navier-stokes/centered.h"
#include "navier-stokes/perp.h"

/* ============================================================================
   PARAMETERS - Modify these to tune the simulation
   ============================================================================ */

// Domain parameters
#ifndef DOMAIN_SIZE
#define DOMAIN_SIZE 1.0    // Domain side length L
#endif

#ifndef REYNOLDS
#define REYNOLDS 0.1       // Reynolds number (tunable)
#endif

#ifndef INLET_VEL
#define INLET_VEL 1.0      // Inlet flow velocity
#endif

// Mesh parameters
#ifndef LEVEL_MAX
#define LEVEL_MAX 9        // Maximum refinement level
#endif

#ifndef LEVEL_MIN
#define LEVEL_MIN 4        // Minimum refinement level
#endif

// Simulation parameters
#ifndef MAX_TIME
#define MAX_TIME 100.0     // Maximum simulation time
#endif

#ifndef CFL_NUMBER
#define CFL_NUMBER 0.5     // CFL number for stability
#endif

/* ============================================================================
   GLOBALS
   ============================================================================ */

double L0, RADIUS, Re, U_in, MU, RHO;
int max_iter = 1000;
FILE *drag_file;

/* ============================================================================
   INITIALIZATION
   ============================================================================ */

event init(i = 0) {
  // Set parameters
  L0 = DOMAIN_SIZE;
  RADIUS = L0 / 4.0;        // Sphere diameter = L0/2, so radius = L0/4
  Re = REYNOLDS;
  U_in = INLET_VEL;
  RHO = 1.0;
  
  // Dynamic viscosity: Re = rho * U * L / mu
  // For Stokes flow: mu = rho * U * L / Re
  mu = RHO * U_in * L0 / Re;
  
  // Domain setup
  origin(-L0/2, -L0/2, -L0/2);
  
  // Initial mesh
  init_grid(1 << LEVEL_MIN);
  
  // CFL-based timestep
  dt = CFL_NUMBER * L0 / U_in;
  
  // Open output file for drag history
  if (pid() == 0) {
    drag_file = fopen("drag_history.txt", "w");
    fprintf(drag_file, "# Time\tF_x\tF_y\tF_z\tF_mag\tCd\n");
  }
  
  if (pid() == 0) {
    fprintf(stderr, "\n=== STOKES FLOW AROUND SPHERE ===\n");
    fprintf(stderr, "Domain size: %.4f\n", L0);
    fprintf(stderr, "Sphere radius: %.4f (diameter: %.4f)\n", RADIUS, 2*RADIUS);
    fprintf(stderr, "Reynolds number: %.4e\n", Re);
    fprintf(stderr, "Dynamic viscosity: %.4e\n", mu);
    fprintf(stderr, "Inlet velocity: %.4f\n", U_in);
    fprintf(stderr, "Max refinement level: %d\n", LEVEL_MAX);
    fprintf(stderr, "====================================\n\n");
  }
}

/* ============================================================================
   BOUNDARY CONDITIONS
   ============================================================================ */

// Inlet (left): uniform flow in x-direction
u.x[left] = dirichlet(U_in);
u.y[left] = dirichlet(0);
u.z[left] = dirichlet(0);
p[left] = neumann(0);

// Outlet (right): zero-gradient
u.x[right] = neumann(0);
u.y[right] = neumann(0);
u.z[right] = neumann(0);
p[right] = dirichlet(0);

// Side walls: symmetry (zero normal velocity, zero normal gradient tangential)
u.x[front] = neumann(0);
u.y[front] = dirichlet(0);
u.z[front] = dirichlet(0);

u.x[back] = neumann(0);
u.y[back] = dirichlet(0);
u.z[back] = dirichlet(0);

u.x[bottom] = neumann(0);
u.y[bottom] = dirichlet(0);
u.z[bottom] = dirichlet(0);

u.x[top] = neumann(0);
u.y[top] = dirichlet(0);
u.z[top] = dirichlet(0);

/* ============================================================================
   EMBEDDED BOUNDARY - Sphere Definition
   ============================================================================ */

/**
 * Distance function defining the sphere as embedded boundary
 * Negative inside sphere, positive outside
 */
double sphere_distance(double x, double y, double z) {
  double r = sqrt(x*x + y*y + z*z);
  return r - RADIUS;
}

/**
 * Initialize embedded boundary on the mesh
 * fractions() computes volume fractions based on the distance function
 */
event init_embed(i = 0) {
  fractions(cs, sphere_distance);
}

/**
 * Apply no-slip boundary condition on embedded boundary (sphere surface)
 */
event sphere_bc(i++; i <= max_iter) {
  foreach() {
    if (cs[] < 1.0) {
      // Cell is inside or at embedded boundary (cs < 1 means not fully fluid)
      u.x[] = 0.0;
      u.y[] = 0.0;
      u.z[] = 0.0;
    }
  }
}

/* ============================================================================
   DRAG FORCE CALCULATION
   ============================================================================ */

void calculate_drag(double time_val) {
  /**
   * Calculate drag force on embedded boundary sphere
   * Uses volume fraction (cs) for accurate surface integration
   */
  double Fx = 0.0, Fy = 0.0, Fz = 0.0;
  double pressure_drag_x = 0.0, viscous_drag_x = 0.0;
  
  // Loop over cells near sphere surface using embedded boundary
  foreach(reduction(+:Fx) reduction(+:Fy) reduction(+:Fz) 
          reduction(+:pressure_drag_x) reduction(+:viscous_drag_x)) {
    
    double cs_val = cs[];
    double h = L0 / pow(2.0, level);
    
    // Only integrate in cut cells (0 < cs < 1) where embedded boundary exists
    if (cs_val > 0.0 && cs_val < 1.0) {
      double r = sqrt(x*x + y*y + z*z);
      
      if (r > 0) {
        // Surface normal (pointing outward from sphere)
        double nx = x / r;
        double ny = y / r;
        double nz = z / r;
        
        // Effective surface area from volume fraction
        double dS = 6.0 * h * h * (1.0 - cs_val);
        
        // Pressure stress
        double sigma_p_x = -p[] * nx;
        double sigma_p_y = -p[] * ny;
        double sigma_p_z = -p[] * nz;
        
        // Viscous stress components
        // tau_ij = mu * (du_i/dx_j + du_j/dx_i)
        double du_dx = (u.x[] - u.x[-1,0,0]) / h;
        double du_dy = (u.x[] - u.x[0,-1,0]) / h;
        double du_dz = (u.x[] - u.x[0,0,-1]) / h;
        
        double dv_dx = (u.y[] - u.y[-1,0,0]) / h;
        double dv_dy = (u.y[] - u.y[0,-1,0]) / h;
        double dv_dz = (u.y[] - u.y[0,0,-1]) / h;
        
        double dw_dx = (u.z[] - u.z[-1,0,0]) / h;
        double dw_dy = (u.z[] - u.z[0,-1,0]) / h;
        double dw_dz = (u.z[] - u.z[0,0,-1]) / h;
        
        // Viscous stress tensor components
        double tau_xx = mu * (2.0*du_dx);
        double tau_yy = mu * (2.0*dv_dy);
        double tau_zz = mu * (2.0*dw_dz);
        double tau_xy = mu * (du_dy + dv_dx);
        double tau_xz = mu * (du_dz + dw_dx);
        double tau_yz = mu * (dv_dz + dw_dy);
        
        // Force contributions
        double sigma_v_x = tau_xx*nx + tau_xy*ny + tau_xz*nz;
        double sigma_v_y = tau_xy*nx + tau_yy*ny + tau_yz*nz;
        double sigma_v_z = tau_xz*nx + tau_yz*ny + tau_zz*nz;
        
        // Accumulate forces
        Fx += (sigma_p_x + sigma_v_x) * dS;
        Fy += (sigma_p_y + sigma_v_y) * dS;
        Fz += (sigma_p_z + sigma_v_z) * dS;
        
        pressure_drag_x += sigma_p_x * dS;
        viscous_drag_x += sigma_v_x * dS;
      }
    }
  }
  
  // Drag coefficient
  // Cd = 2*F / (rho * U^2 * A)
  // where A = pi*r^2 for sphere cross-section
  double A = M_PI * RADIUS * RADIUS;
  double F_mag = sqrt(Fx*Fx + Fy*Fy + Fz*Fz);
  double Cd = 2.0 * F_mag / (RHO * U_in * U_in * A + 1e-10);
  
  // Theoretical Stokes drag: F = 6*pi*mu*r*U
  double F_stokes = 6.0 * M_PI * mu * RADIUS * U_in;
  double Cd_stokes = 2.0 * F_stokes / (RHO * U_in * U_in * A);
  
  if (pid() == 0) {
    fprintf(stderr, "t=%.4f: F=(%.6e, %.6e, %.6e), |F|=%.6e, Cd=%.6e\n",
            time_val, Fx, Fy, Fz, F_mag, Cd);
    fprintf(stderr, "  Pressure drag: %.6e, Viscous drag: %.6e\n",
            pressure_drag_x, viscous_drag_x);
    fprintf(stderr, "  Stokes theory: F=%.6e, Cd=%.6e\n", F_stokes, Cd_stokes);
    
    fprintf(drag_file, "%.6e\t%.6e\t%.6e\t%.6e\t%.6e\t%.6e\n",
            time_val, Fx, Fy, Fz, F_mag, Cd);
    fflush(drag_file);
  }
}
  }
  
  // Drag coefficient
  // Cd = 2*F / (rho * U^2 * A)
  // where A = pi*r^2 for sphere cross-section
  double A = M_PI * RADIUS * RADIUS;
  double F_mag = sqrt(Fx*Fx + Fy*Fy + Fz*Fz);
  double Cd = 2.0 * F_mag / (RHO * U_in * U_in * A + 1e-10);
  
  // Theoretical Stokes drag: F = 6*pi*mu*r*U
  double F_stokes = 6.0 * M_PI * mu * RADIUS * U_in;
  double Cd_stokes = 2.0 * F_stokes / (RHO * U_in * U_in * A);
  
  if (pid() == 0) {
    fprintf(stderr, "t=%.4f: F=(%.6e, %.6e, %.6e), |F|=%.6e, Cd=%.6e\n",
            time_val, Fx, Fy, Fz, F_mag, Cd);
    fprintf(stderr, "  Pressure drag: %.6e, Viscous drag: %.6e\n",
            pressure_drag_x, viscous_drag_x);
    fprintf(stderr, "  Stokes theory: F=%.6e, Cd=%.6e\n", F_stokes, Cd_stokes);
    
    fprintf(drag_file, "%.6e\t%.6e\t%.6e\t%.6e\t%.6e\t%.6e\n",
            time_val, Fx, Fy, Fz, F_mag, Cd);
    fflush(drag_file);
  }
}

event compute_drag(i += 10; i <= max_iter) {
  calculate_drag(t);
}

/* ============================================================================
   ADAPTIVE MESH REFINEMENT
   ============================================================================ */

event adapt(i += 5; i <= max_iter) {
  // Update embedded boundary after mesh changes
  fractions(cs, sphere_distance);
  
  // Refine based on velocity, pressure, and embedded boundary
  adapt_wavelet((scalar*){u.x, u.y, u.z, p},
                (double[]){1e-2, 1e-2, 1e-2, 1e-2},
                LEVEL_MAX, LEVEL_MIN);
}

/* ============================================================================
   DIAGNOSTICS
   ============================================================================ */

event diagnostics(i += 10; i <= max_iter) {
  double umax = 0;
  long n_cells = 0;
  foreach(reduction(max:umax) reduction(+:n_cells)) {
    if (cs[] > 0.0) {  // Only count fluid cells
      double umag = sqrt(u.x[]*u.x[] + u.y[]*u.y[] + u.z[]*u.z[]);
      if (umag > umax) umax = umag;
      n_cells++;
    }
  }
  
  #ifdef USE_MPI
  // MPI reduction to get global maximum and sum
  double umax_global = umax;
  long n_cells_global = n_cells;
  MPI_Allreduce(&umax, &umax_global, 1, MPI_DOUBLE, MPI_MAX, MPI_COMM_WORLD);
  MPI_Allreduce(&n_cells, &n_cells_global, 1, MPI_LONG, MPI_SUM, MPI_COMM_WORLD);
  umax = umax_global;
  n_cells = n_cells_global;
  #endif
  
  if (pid() == 0) {
    fprintf(stderr, "i=%d, t=%.6f, dt=%.6e, max_u=%.6e, cells=%ld\n",
            i, t, dt, umax, n_cells);
  }
}
  
  if (pid() == 0) {
    fprintf(stderr, "i=%d, t=%.6f, dt=%.6e, max_u=%.6e, cells=%ld\n",
            i, t, dt, umax, grid_points());
  }
}

/* ============================================================================
   CONVERGENCE CHECK FOR STEADY STATE
   ============================================================================ */

event stopping(i += 20; i <= max_iter) {
  double res = 0.0;
  
  // Parallel reduction for residual check (only in fluid)
  foreach(reduction(+:res)) {
    if (cs[] > 0.0) {  // Only in fluid region
      res += (u.x[] - u.x[0,0,0])*(u.x[] - u.x[0,0,0]);
    }
  }
  
  #ifdef USE_MPI
  double res_global = res;
  MPI_Allreduce(&res, &res_global, 1, MPI_DOUBLE, MPI_SUM, MPI_COMM_WORLD);
  res = res_global;
  #endif
  
  if (res < 1e-6 && i > 50) {
    if (pid() == 0) {
      fprintf(stderr, "\nSteady state reached at t=%.6f\n", t);
    }
    max_iter = i;  // Stop iteration
  }
}
  
  if (res < 1e-6 && i > 50) {
    if (pid() == 0) {
      fprintf(stderr, "\nSteady state reached at t=%.6f\n", t);
    }
    max_iter = i;  // Stop iteration
  }
}

/* ============================================================================
   OUTPUT AND VISUALIZATION
   ============================================================================ */

event output(i += 50; i <= max_iter) {
  char name[80];
  sprintf(name, "output-%05d.vtu", i);
  FILE *fp = fopen(name, "w");
  output_vtu((scalar*){p, u.x, u.y, u.z, cs}, (vector*){u}, fp);
  fclose(fp);
}

event cleanup(t = end) {
  if (pid() == 0) {
    fprintf(stderr, "\n=== SIMULATION COMPLETED ===\n");
    fprintf(stderr, "Final time: %.6f\n", t);
    fprintf(stderr, "Output files saved: output-*.vtu, drag_history.txt\n");
    fclose(drag_file);
  }
}

/* ============================================================================
   MAIN
   ============================================================================ */

int main() {
  // Set gravity to zero (no body forces in Stokes flow)
  G = 0;
  
  // Set maximum iterations and simulation time
  max_iter = MAX_TIME / (CFL_NUMBER * DOMAIN_SIZE / INLET_VEL) * 10;
  TMAX = MAX_TIME;
  
  return 0;
}
