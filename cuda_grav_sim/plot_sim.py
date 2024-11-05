import matplotlib.pyplot as plt
import matplotlib.animation as animation
import numpy as np
import sys

def read_simulation_data(filename):
    """
    Reads the simulation data from the given filename.
    Returns a dictionary with body names as keys and their x, y positions over time.
    """
    positions = {}
    with open(filename, 'r') as file:
        for line_number, line in enumerate(file, 1):
            tokens = line.strip().split()
            if not tokens:
                continue  # Skip empty lines
            if tokens[0].startswith('#'):
                continue  # Skip comment lines
            if len(tokens) % 4 != 0:
                print(f"Warning: Line {line_number} has incomplete data and will be skipped.")
                continue  # Ensure data integrity

            num_bodies = len(tokens) // 4
            for i in range(num_bodies):
                name = tokens[i*4]
                x = float(tokens[i*4 + 1])
                y = float(tokens[i*4 + 2])
                # z = float(tokens[i*4 + 3])  # Not used since z=0

                if name not in positions:
                    positions[name] = {'x': [], 'y': []}
                positions[name]['x'].append(x)
                positions[name]['y'].append(y)
    return positions

def plot_trajectories(positions, selected_bodies=None, save=False, filename='trajectories.png'):
    """
    Plots the trajectories of celestial bodies.
    - positions: Dictionary with body names as keys and their x, y positions over time.
    - selected_bodies: List of body names to plot. If None, plots all.
    - save: If True, saves the plot to a file.
    - filename: Filename for saving the plot.
    """
    plt.figure(figsize=(10, 10))
    ax = plt.gca()
    ax.set_aspect('equal', adjustable='box')

    # Determine which bodies to plot
    if selected_bodies is None:
        selected_bodies = list(positions.keys())

    # Color map
    cmap = plt.get_cmap('tab20')
    colors = cmap(np.linspace(0, 1, len(selected_bodies)))

    for idx, (name, data) in enumerate(positions.items()):
        if selected_bodies and name not in selected_bodies:
            continue  # Skip bodies not selected

        plt.plot(data['x'], data['y'], label=name, color=colors[idx % len(colors)])
        plt.scatter(data['x'][0], data['y'][0], color=colors[idx % len(colors)], marker='o')  # Start
        plt.scatter(data['x'][-1], data['y'][-1], color=colors[idx % len(colors)], marker='x')  # End

    plt.title('Celestial Bodies Trajectories')
    plt.xlabel('X Position (m)')
    plt.ylabel('Y Position (m)')
    plt.legend()
    plt.grid(True)

    if save:
        plt.savefig(filename, dpi=300)
        print(f"Plot saved as {filename}")
    else:
        plt.show()

def plot_animation(positions, selected_bodies=None, save=False, filename='trajectories.gif'):
    """
    Creates an animation of celestial bodies moving over time.
    - positions: Dictionary with body names as keys and their x, y positions over time.
    - selected_bodies: List of body names to animate. If None, animates all.
    - save: If True, saves the animation to a GIF file.
    - filename: Filename for saving the animation.
    """
    if selected_bodies is None:
        selected_bodies = list(positions.keys())

    fig, ax = plt.subplots(figsize=(10, 10))
    ax.set_aspect('equal', adjustable='box')
    ax.set_title('Celestial Bodies Animation')
    ax.set_xlabel('X Position (m)')
    ax.set_ylabel('Y Position (m)')
    ax.grid(True)

    # Color map
    cmap = plt.get_cmap('tab20')
    colors = cmap(np.linspace(0, 1, len(selected_bodies)))

    # Initialize lines and points
    lines = {}
    points = {}
    for idx, name in enumerate(selected_bodies):
        lines[name], = ax.plot([], [], label=name, color=colors[idx % len(colors)])
        points[name], = ax.plot([], [], 'o', color=colors[idx % len(colors)])

    ax.legend()

    # Determine the number of frames
    num_frames = max(len(data['x']) for data in positions.values())

    def init():
        for name in selected_bodies:
            lines[name].set_data([], [])
            points[name].set_data([], [])
        return list(lines.values()) + list(points.values())

    def animate(frame):
        for idx, name in enumerate(selected_bodies):
            x = positions[name]['x'][:frame]
            y = positions[name]['y'][:frame]
            lines[name].set_data(x, y)
            if frame < len(positions[name]['x']):
                points[name].set_data(x[-1], y[-1])
        return list(lines.values()) + list(points.values())

    ani = animation.FuncAnimation(fig, animate, init_func=init,
                                  frames=num_frames, interval=50, blit=True)

    if save:
        ani.save(filename, writer='imagemagick', fps=30)
        print(f"Animation saved as {filename}")
    else:
        plt.show()

def main():
    """
    Main function to execute the plotting.
    """
    import argparse

    parser = argparse.ArgumentParser(description='Plot simulation data from solargraph.dat')
    parser.add_argument('--file', type=str, default='solargraph.dat',
                        help='Path to the simulation data file (default: solargraph.dat)')
    parser.add_argument('--plot', type=str, choices=['trajectories', 'animation'], default='trajectories',
                        help='Type of plot to generate (default: trajectories)')
    parser.add_argument('--save', action='store_true',
                        help='Save the plot instead of displaying it')
    parser.add_argument('--filename', type=str, default='trajectories.png',
                        help='Filename for saving the plot (default: trajectories.png)')
    parser.add_argument('--animate_filename', type=str, default='trajectories.gif',
                        help='Filename for saving the animation (default: trajectories.gif)')
    parser.add_argument('--bodies', type=str, nargs='*',
                        help='List of bodies to plot/animate. If not specified, all are plotted.')

    args = parser.parse_args()

    # Read data
    print(f"Reading simulation data from {args.file}...")
    positions = read_simulation_data(args.file)
    if not positions:
        print("No data found. Exiting.")
        sys.exit(1)
    print(f"Found {len(positions)} bodies.")

    # Determine selected bodies
    if args.bodies:
        selected_bodies = args.bodies
        # Validate selected bodies
        invalid_bodies = [b for b in selected_bodies if b not in positions]
        if invalid_bodies:
            print(f"Error: The following bodies were not found in the data: {invalid_bodies}")
            sys.exit(1)
    else:
        selected_bodies = None  # Plot all

    # Plot based on user choice
    if args.plot == 'trajectories':
        plot_trajectories(positions, selected_bodies, save=args.save, filename=args.filename)
    elif args.plot == 'animation':
        plot_animation(positions, selected_bodies, save=args.save, filename=args.animate_filename)

if __name__ == '__main__':
    main()

