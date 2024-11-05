import random
import math

# Constants
NUM_BODIES = 1000
SUN_MASS = 1.9891e30  # kg
SUN_DIAM = 1.391684e9  # meters
G = 6.67e-11  # gravitational constant

# Function to generate a unique name
def generate_name(index):
    return f"Body{index}"

# Function to calculate orbital period based on semi-major axis using Kepler's Third Law
# T^2 = (4 * pi^2 * a^3) / (G * (M + m))
# For simplicity, assume m << M (mass of Sun)
def calculate_orbital_period(semi_major_axis, mass=SUN_MASS):
    return math.sqrt((4 * math.pi**2 * semi_major_axis**3) / (G * mass)) / (60*60*24)  # in days

# Function to generate realistic mass (kg)
def generate_mass():
    # Range from 1e20 kg (small asteroids) to 1e28 kg (massive dwarf planets)
    return random.uniform(1e20, 1e28)

# Function to generate diameter (meters) based on mass
def generate_diameter(mass):
    # Assume density varies between 1000 kg/m^3 to 5000 kg/m^3
    density = random.uniform(1000, 5000)
    volume = mass / density
    radius = (3 * volume / (4 * math.pi))**(1/3)
    diameter = 2 * radius
    return diameter

# Function to generate orbital distances (meters)
def generate_orbital_distances(index):
    # Distribute semi-major axis between 0.4 AU to 40 AU
    # 1 AU = 1.496e11 meters
    semi_major_axis = random.uniform(0.4 * 1.496e11, 40 * 1.496e11)
    # Eccentricity between 0 (circular) and 0.2 (somewhat elliptical)
    eccentricity = random.uniform(0, 0.2)
    perihelion = semi_major_axis * (1 - eccentricity)
    aphelion = semi_major_axis * (1 + eccentricity)
    return perihelion, aphelion, semi_major_axis

# Function to generate rotational period (hours)
def generate_rotational_period():
    return random.uniform(5, 1000)  # hours

# Function to generate axial tilt (degrees)
def generate_axial_tilt():
    return random.uniform(0, 90)  # degrees

# Function to generate orbital inclination (degrees)
def generate_orbital_inclination():
    return random.uniform(0, 30)  # degrees

# Open the file for writing
with open('solarsys.dat', 'w') as f:
    # Write header
    f.write("#Name\tOrbits\tMass(kg)\tDiam(m)\tPerihelion(m)\tAphelion(m)\torbPeriod(days)\trotationalPeriod(hours)\taxialtilt(deg)\torbinclin(deg)\n")
    
    # Add the Sun
    f.write("Sun\tNaN\t{:.4e}\t{:.6e}\t0\t0\t0\t587.28\t0\t0\n".format(SUN_MASS, SUN_DIAM))
    
    # Generate other bodies
    for i in range(1, NUM_BODIES + 1):
        name = generate_name(i)
        orbits = "Sun"  # All orbiting the Sun for simplicity
        mass = generate_mass()
        diameter = generate_diameter(mass)
        perihelion, aphelion, semi_major_axis = generate_orbital_distances(i)
        orb_period = calculate_orbital_period(semi_major_axis)
        rotational_period = generate_rotational_period()
        axial_tilt = generate_axial_tilt()
        orbital_inclination = generate_orbital_inclination()
        
        # Format the data with appropriate precision
        line = f"{name}\t{orbits}\t{mass:.4e}\t{diameter:.6e}\t{perihelion:.6e}\t{aphelion:.6e}\t{orb_period:.2f}\t{rotational_period:.2f}\t{axial_tilt:.2f}\t{orbital_inclination:.2f}\n"
        f.write(line)

print(f"Generated solarsys.dat with {NUM_BODIES + 1} celestial bodies.")

