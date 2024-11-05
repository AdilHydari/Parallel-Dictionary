#include <cuda.h>
#include <cuda_runtime.h>
#include <iostream>
#include <vector>
#include <unordered_map>
#include <cmath>
#include <string>
#include <fstream>
#include <sstream>
#include <random>
#include <chrono>
#include <unistd.h>

// There is no c++20 compatibility for the nvcc on amarel
// #include <numbers> 

using namespace std;

#define PI 3.14159265358979323846f

// Constants
const double year = 365.25 * 24 * 60 * 60;
const float G = 6.67e-11f;
random_device rd;
mt19937 gen(0); // Seeded for reproducibility
uniform_real_distribution<> dis(0, 1);

const int print_every = 100;
const int graph_every = 1000;

struct body {
    uint32_t id;
    float Gm;
    float x, y, z;
    float vx, vy, vz;
    float ax, ay, az;
    float old_ax, old_ay, old_az;
};

struct Bodies {
    float *Gm;
    float *x, *y, *z;
    float *vx, *vy, *vz;
    float *ax, *ay, *az;
    float *old_ax, *old_ay, *old_az;
};

// CUDA Kernels

__global__ void compute_acceleration_kernel(int n, Bodies bodies) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;

    float ax = 0.0f;
    float ay = 0.0f;
    float az = 0.0f;

    float x1 = bodies.x[i];
    float y1 = bodies.y[i];
    float z1 = bodies.z[i];

    for (int j = 0; j < n; j++) {
        if (i == j) continue;

        float dx = bodies.x[j] - x1;
        float dy = bodies.y[j] - y1;
        float dz = bodies.z[j] - z1;

        float r2 = dx * dx + dy * dy + dz * dz + 1e-10f; // Softening factor
        float inv_r3 = rsqrtf(r2 * r2 * r2); // Inverse of r^3

        ax += bodies.Gm[j] * dx * inv_r3;
        ay += bodies.Gm[j] * dy * inv_r3;
        az += bodies.Gm[j] * dz * inv_r3;
    }

    bodies.ax[i] = ax;
    bodies.ay[i] = ay;
    bodies.az[i] = az;
}

__global__ void step_forward_kernel(int n, Bodies bodies, float dt) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= n) return;

    // Update velocities
    bodies.vx[i] += bodies.ax[i] * dt;
    bodies.vy[i] += bodies.ay[i] * dt;
    bodies.vz[i] += bodies.az[i] * dt;

    // Update positions
    bodies.x[i] += bodies.vx[i] * dt;
    bodies.y[i] += bodies.vy[i] * dt;
    bodies.z[i] += bodies.vz[i] * dt;
}

class GravSim {
public:
    bool verbose;
    enum class configuration {CIRCULAR, ELLIPTICAL_2D, CIRCULAR_RANDOM, ELLIPTICAL_3D};
private:
    ofstream graphfile;
    vector<string> names;
    unordered_map<string, uint32_t> orbit_map;
    vector<struct body> bodies;

    Bodies device_bodies;
    int n; // # of bodies
    float dt;
    uint64_t num_steps;
    uint64_t timestep;

    void read_line(ifstream &infile, configuration config);
    void add_body(const string& name, uint32_t orbiting_body, float m, float x, float y, float z, float vx, float vy, float vz);
    void add_body_circular(const string& name, uint32_t orbiting_body, float m, float a, float e, float orbPeriod);
    void add_body_circular_random(const string& name, uint32_t orbiting_body, float m, float a, float e, float orbPeriod);
    void add_body_elliptical(const string& name, uint32_t orbiting_body, float m, float a, float e, float orbPeriod);
public:
    GravSim(const char filename[], float timestep_dt, float duration, bool verbose_flag, uint32_t print_every, uint32_t graph_every, configuration config);
    ~GravSim();
    GravSim(const GravSim &orig) = delete;
    GravSim& operator=(const GravSim &rhs) = delete;
    void compute_acceleration_cuda(int threads_per_block = 256);
    void step_forward_cuda(float dt, int threads_per_block = 256);
    void print_system() const;
    void graph_system();
};

// GravSim Methods

void GravSim::add_body(const string& name, uint32_t orbiting_body, float m, float x, float y, float z, float vx, float vy, float vz) {
    bodies.push_back({uint32_t(names.size()), G * m, x, y, z, vx, vy, vz, 0, 0, 0});
    names.push_back(name);
    orbit_map[name] = names.size() - 1;
}

void GravSim::add_body_circular(const string& name, uint32_t orbiting_body, float m, float a, float e, float orbPeriod) {
    float Gm = bodies[orbiting_body].Gm;
    float v0 = sqrt(Gm / a); // Orbit velocity
    if (orbPeriod < 0) v0 = -v0;
    float x = bodies[orbiting_body].x + a;
    add_body(name, orbiting_body, m, x, 0, 0, 0, v0, 0);
}

void GravSim::add_body_circular_random(const string& name, uint32_t orbiting_body, float m, float a, float e, float orbPeriod) {
    float v0 = sqrt(bodies[orbiting_body].Gm / a);
    if (orbPeriod < 0) v0 = -v0;
    float angle = dis(gen) * 2 * PI;
    float x = bodies[orbiting_body].x + a * cos(angle);
    float y = bodies[orbiting_body].y + a * sin(angle);
    add_body(name, orbiting_body, m, x, y, 0, -v0 * sin(angle), v0 * cos(angle), 0);
}

void GravSim::add_body_elliptical(const string& name, uint32_t orbiting_body, float m, float a, float e, float orbPeriod) {
    float Gm = bodies[orbiting_body].Gm;
    float v0 = sqrt(Gm * (1 - e * e) / a); // Vis-viva equation
    float angle = dis(gen) * 2 * PI;
    add_body(name, orbiting_body, m, a * cos(angle), a * sin(angle), 0, -v0 * sin(angle), v0 * cos(angle), 0);
}

void GravSim::read_line(ifstream &infile, configuration config) {
    char buffer[4096];
    infile.getline(buffer, 4096);
    if (infile.fail()) return;
    if (buffer[0] == '#') return; //Omit comments 
    if (buffer[0] == ' ' || buffer[0] == '\0') return; // Omit blank lines
    stringstream ss(buffer);
    string name, orbits;
    float mass, diam, perihelion, aphelion, orbPeriod, rotationalPeriod, axialtilt, orbinclin;
    ss >> name >> orbits >> mass >> diam >> perihelion >> aphelion >> orbPeriod >> rotationalPeriod >> axialtilt >> orbinclin;
    if (bodies.size() == 0) {
        // Sun first
        add_body(name, 0, mass, 0, 0, 0, 0, 0, 0);
        return;
    }
    // Use orbits to find the parent body
    auto it = orbit_map.find(orbits);
    uint32_t orbiting_body = (it != orbit_map.end()) ? it->second : 0; // Default to Sun if not found

    if (config == configuration::CIRCULAR) {    
        add_body_circular(name, orbiting_body, mass, perihelion, 0, orbPeriod);
    } else if (config == configuration::CIRCULAR_RANDOM) {
        add_body_circular_random(name, orbiting_body, mass, perihelion, 0, orbPeriod);
    } else if (config == configuration::ELLIPTICAL_2D) {
        add_body_elliptical(name, orbiting_body, mass, perihelion, aphelion, orbPeriod);
    } else if (config == configuration::ELLIPTICAL_3D) {
        // TODO: Implement elliptical 3D
    }
}

GravSim::GravSim(const char filename[], float timestep_dt, float duration, bool verbose_flag, uint32_t print_every_param, uint32_t graph_every_param, configuration config) 
    : verbose(verbose_flag), graphfile("solargraph.dat"), dt(timestep_dt), num_steps(duration / timestep_dt), timestep(0) {

    ifstream infile(filename);
    if (!infile.is_open()) {
        cerr << "Failed to open input file: " << filename << endl;
        exit(EXIT_FAILURE);
    }
    while (infile) {
        read_line(infile, config);
    }
    infile.close();

    n = bodies.size();

    // Allocate Unified Memory https://www.olcf.ornl.gov/wp-content/uploads/2019/06/06_Managed_Memory.pdf
    cudaError_t err;
    err = cudaMallocManaged(&device_bodies.Gm, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (Gm): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.x, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (x): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.y, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (y): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.z, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (z): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.vx, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (vx): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.vy, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (vy): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.vz, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (vz): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.ax, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (ax): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.ay, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (ay): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.az, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (az): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.old_ax, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (old_ax): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.old_ay, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (old_ay): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }
    err = cudaMallocManaged(&device_bodies.old_az, n * sizeof(float));
    if (err != cudaSuccess) { cerr << "CUDA malloc error (old_az): " << cudaGetErrorString(err) << endl; exit(EXIT_FAILURE); }

    for (int i = 0; i < n; i++) {
        device_bodies.Gm[i] = bodies[i].Gm;
        device_bodies.x[i] = bodies[i].x;
        device_bodies.y[i] = bodies[i].y;
        device_bodies.z[i] = bodies[i].z;
        device_bodies.vx[i] = bodies[i].vx;
        device_bodies.vy[i] = bodies[i].vy;
        device_bodies.vz[i] = bodies[i].vz;
        device_bodies.ax[i] = bodies[i].ax;
        device_bodies.ay[i] = bodies[i].ay;
        device_bodies.az[i] = bodies[i].az;
        device_bodies.old_ax[i] = bodies[i].old_ax;
        device_bodies.old_ay[i] = bodies[i].old_ay;
        device_bodies.old_az[i] = bodies[i].old_az;
    }

    // Main simulation loop
    cout << "Starting simulation with " << n << " bodies, num_steps=" << num_steps << endl;
    for (int i = 0; i < num_steps; i++) {
        // Old accelerations
        for (int j = 0; j < n; j++) {
            device_bodies.old_ax[j] = device_bodies.ax[j];
            device_bodies.old_ay[j] = device_bodies.ay[j];
            device_bodies.old_az[j] = device_bodies.az[j];
        }

        compute_acceleration_cuda();

        step_forward_cuda(dt);

        if (verbose) {
            timestep = i;
            if (i % print_every == 0) {
                print_system();
            }
            if (i % graph_every == 0) {
                graph_system();
            }
        }
    }

    cudaDeviceSynchronize();
}

GravSim::~GravSim() {
    // Free Unified Memory
    cudaFree(device_bodies.Gm);
    cudaFree(device_bodies.x);
    cudaFree(device_bodies.y);
    cudaFree(device_bodies.z);
    cudaFree(device_bodies.vx);
    cudaFree(device_bodies.vy);
    cudaFree(device_bodies.vz);
    cudaFree(device_bodies.ax);
    cudaFree(device_bodies.ay);
    cudaFree(device_bodies.az);
    cudaFree(device_bodies.old_ax);
    cudaFree(device_bodies.old_ay);
    cudaFree(device_bodies.old_az);
}

void GravSim::compute_acceleration_cuda(int threads_per_block) {
    int blocks = (n + threads_per_block - 1) / threads_per_block;
    compute_acceleration_kernel<<<blocks, threads_per_block>>>(n, device_bodies);
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        cerr << "Failed to launch compute_acceleration_kernel: " << cudaGetErrorString(err) << endl;
        exit(EXIT_FAILURE);
    }
    cudaDeviceSynchronize();
}

void GravSim::step_forward_cuda(float dt, int threads_per_block) {
    int blocks = (n + threads_per_block - 1) / threads_per_block;
    step_forward_kernel<<<blocks, threads_per_block>>>(n, device_bodies, dt);
    cudaError_t err = cudaGetLastError();
    if (err != cudaSuccess) {
        cerr << "Failed to launch step_forward_kernel: " << cudaGetErrorString(err) << endl;
        exit(EXIT_FAILURE);
    }
    cudaDeviceSynchronize();
}

void GravSim::print_system() const {
    for (int i = 0; i < n; i++) {
        cout << names[i] << " " 
             << device_bodies.x[i] << "," 
             << device_bodies.y[i] << "," 
             << device_bodies.z[i] << "   " 
             << device_bodies.vx[i] << "," 
             << device_bodies.vy[i] << "," 
             << device_bodies.vz[i] << endl;
    }
}

void GravSim::graph_system() {
    for (int i = 0; i < n; i++) {
        graphfile << names[i] << ' ' 
                  << device_bodies.x[i] << ' ' 
                  << device_bodies.y[i] << ' ' 
                  << device_bodies.z[i] << ' ';
    }
    graphfile << '\n';
}

// Main 

int main(int argc, char **argv) {
    const char *filename = (argc > 1) ? argv[1] : "solarsys.dat";
    float dt = 1000.0f; // Timestep in seconds
    float duration = year; // One year
    bool verbose = true;
    uint32_t print_every = static_cast<uint32_t>(31536000 / dt); // Print once per year
    uint32_t graph_every = static_cast<uint32_t>(86400 / dt); // Graph once per day

    GravSim sim(filename, dt, duration, verbose, print_every, graph_every, GravSim::configuration::CIRCULAR_RANDOM);
    sim.print_system();
    sim.graph_system();

    return 0;
}

