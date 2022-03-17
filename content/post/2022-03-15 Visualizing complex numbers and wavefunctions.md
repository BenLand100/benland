---
title: 'Visualizing complex numbers and wavefunctions in one and two dimensions'
date: '2022-03-17'
categories: 
  - Math
  - Programming
  - Physics
description: An alternative way to visualize the complex numbers and functions returning complex numbers (wavefunctions) from a previous post on simulating quantum mechanics. Also, generalizing the simulations to two dimensions, and calculating the lowest energy states of the Hydrogen atom in 2D.
slug: complex-wavefunction-visualization
toc: true
---


{{< figure src="/images/hsv.png" class="right" caption="The HSV colorspace, matching angle to hue around the circle, and saturation to the radius.">}}

In [a previous post on simulating quantum mechanics](/post/2022/03/09/quantum-mechanics-simulation/), I visualized the [complex numbers](/post/2021/10/31/fpga-rf-receiver/#an-aside-on-complex-numbers) in the wavefunctions by plotting their real, imaginary, and magnitude (square root of probability) separately.
As I mentioned briefly in that post, this is a bit lacking compared to the more intuitive way to think of complex numbers: as a magnitude and phase (angle).
The magnitude was accounted for, but the real and imaginary parts can obfuscate the phase.

Like an angle, the phase $\alpha$ is cyclic over $[0,2\pi]$ radians or $360$ degrees.
This can be represented by some cyclic color map, as easily as mapping the phase to the hue of a color in the [HSV color space](https://en.wikipedia.org/wiki/HSL_and_HSV), which can make for a visually more intuitive representation of the phase.

Using this scheme, I've opted to shade below the magnitude with a hue determined by the phase, and re-rendered the results from the previous post.
As a bonus, I have also extended the simulation into two dimensions, and added GPU acceleration, which I'll discuss [in the last half](#wave-functions-in-two-dimensions).


## Wave functions in one dimension

The figures in this section are identical wave functions as those in the [previous post](), but visualized with the phase as hue.
Having matplotlib shade under a regular plot as a function of position proved challenging, so I oped for adding the shading to a plot manually.
```python
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.colors import hsv_to_rgb

def polygon(x1,y1,x2,y2,c,ax=None):
    if ax is None:
        ax = plt.gca()
    polygon = plt.Polygon( [ (x1,y1), (x2,y2), (x2,0), (x1,0) ], color=c )
    ax.add_patch(polygon)
    
def complex_plot(x,y,ax=None,**kwargs):
    mag = np.abs(y)
    phase = np.angle(y)/(2*np.pi)
    mask = phase < 0.0
    phase[mask] = 1+phase[mask]
    hsv = np.asarray([phase,np.full_like(phase,0.5),np.ones_like(phase)]).T
    rgb = hsv_to_rgb(hsv[None,:,:])[0]
    cmap = plt.get_cmap('hsv')
    if ax is None:
        ax = plt.gca()
    ax.plot(x,mag,color='k')   
    mask = mag > np.max(mag)*1e-2
    [polygon(x[n],mag[n],x[n+1],mag[n+1],rgb[n],ax=ax) for n in range(len(x)-1) if mask[n] and mask[n+1]]
    ax.set_xlabel('Position')
    ax.set_xlim(-2,2)
    ax.set_ylim(0,None)
    
```
Note that the axis is an optional argument, which proved critical when producing animated visualizations.
```python
from matplotlib.animation import FuncAnimation

def animate(simulation_steps,save_as=None,init_func=None):
    fig, ax = plt.subplots()
    complex_plot(x,simulation_steps[0],ax=ax)
    ax.set_xlim(-2,2)
    ax.set_ylim(0,4)
    if init_func:
        init_func(ax)

    def animate(frame):
        ax.clear()
        complex_plot(x,simulation_steps[frame],ax=ax)
        ax.set_xlim(-2,2)
        ax.set_ylim(0,3)
        if init_func:
            init_func(ax)
    
    anim = FuncAnimation(fig, animate, frames=int(len(simulation_steps)), interval=50)
    plt.close()

    if save_as:
        anim.save(save_as, writer='imagemagick', fps=30)
    
    return anim
```

For the rest of the code and commentary, see the previous post.
I'll just be reproducing the plots here.

{{< figure src="/images/qm_vis/wave_packet.png" class="center" caption="A wave packet with zero momentum is just a real-valued Gaussian distribution. These are complex numbers with the same phase but differing magnitude" >}}

{{< figure src="/images/qm_vis/wave_packet_mom.png" class="center" caption="A wave packet with nonzero momentum still has a magnitude that is a Gaussian distribution, but the complex phase changes as a function of position at a rate proportional to the momentum." >}}

### A free, stationary particle

{{< video src="/images/qm_vis/wave_packet.mp4" class="center" width=720 height=504 >}}

### A free particle with momentum

{{< video src="/images/qm_vis/wave_packet_mom.mp4" class="center" width=720 height=504 >}}

### A particle in a box

{{< video src="/images/qm_vis/wave_packet_box.mp4" class="center" width=720 height=504 >}}

### A particle encounters a barrier

{{< video src="/images/qm_vis/wave_packet_barrier.mp4" class="center" width=720 height=504 >}}

### A particle in a quadratic potential

{{< video src="/images/qm_vis/wave_packet_quad.mp4" class="center" width=720 height=504 >}}

### Quantum harmonic oscillator eigenstates

Evolution of a guess to the three lowest energy states:

{{< video src="/images/qm_vis/quad_0.mp4" class="center" width=720 height=504 >}}

{{< video src="/images/qm_vis/quad_1.mp4" class="center" width=720 height=504 >}}

{{< video src="/images/qm_vis/quad_2.mp4" class="center" width=720 height=504 >}}

Time evolution of the second excited state:

{{< video src="/images/qm_vis/quad_2_evo.mp4" class="center" width=720 height=504 >}}

## Wave functions in two dimensions

I first started playing with phase as hue when trying to visualize a 2D wavefunction.
The major difference, of course, now having four dimensions to visualize: two spatial dimensions, along with the magnitude and phase at every point.
The generalization of the previous plot would be a two dimensional surface in 3D with the third dimension being the magnitude, and shaded with a hue to represent the phase.
Without going to a 3D plot, I opted to stick with the HSV color space and make an image with two axes for space and the the _hue_ for phase and _value_ for magnitude.
This way, large magnitudes are brighter, colored by the phase, which makes for some impressive visualizations.

Of course, simulating in 2D requires changes, including a way to deal with the a wavefunction on a 2D grid as opposed to a 1D grid.
First of all, since integrating the Schrodinger equation in 2D will be much more computationally intense than in 1D, I'll be using [Cupy](https://cupy.dev/) to accelerate most of the math with a GPU.
This ultimately makes the 2D simulations take less time than the 1D simulations, though the smallness of the data in 1D means GPU acceleration would not help much. 
```python
import numpy as np
import cupy as cp
import matplotlib.pyplot as plt
```
This will be the definition of the 2D grid the wavefunction will be sampled on.
```python
x = cp.linspace(-10,10,500)
y = cp.linspace(-10,10,500)
extent = cp.asnumpy(cp.asarray([cp.min(x), cp.max(x), cp.min(y), cp.max(y)]))
xv, yv = cp.meshgrid(x, y, indexing='ij')
deltax = x[1]-x[0]
deltay = y[1]-y[0]
deltaxy = deltax*deltay
```
And here is a way to normalize a wavefunction in 2D
```
def norm(phi):
    norm = cp.sum(cp.square(cp.abs(phi)))*deltaxy
    return phi/cp.sqrt(norm)
```

which is equivalent to satisfying the condition
$$
\int\int \left|\psi(x,y)\right|^2 \\,\\,dxdy = 1
$$

and might be written by a physicist as
$$
\int \left|\psi\right|^2 \\,\\, d\vec{x} = 1
$$
to generalize into any number of dimensions.

### Wave packets

To build an analogous wave packet to the 1D case, one uses a Gaussian profile in both spatial dimensions, and the rate of change of phase in each direction encodes momentum in that direction.
```python
def wave_packet(p_x = 0, p_y = 0, disp_x = 0, disp_y = 0, sqsig = 0.5):
    return norm( cp.exp(1j*xv*p_x) * cp.exp(1j*yv*p_y)
                *cp.exp(-cp.square(xv-disp_x)/sqsig,dtype=complex) 
                *cp.exp(-cp.square(yv-disp_y)/sqsig,dtype=complex))
```

And to display these beauties, the magnitude is converted into a value (brightness) and phase into a hue. I choose a low saturation, here, as before, before because fully saturated hues diminished the ability to perceive the change in magnitude encoded in the value.
```
from matplotlib.colors import hsv_to_rgb

def to_image(z,z_min=0,z_max=None,abssq=False):
    hue = cp.ones(z.shape) if abssq else cp.angle(z)/(2*cp.pi)
    mask = hue < 0.0
    hue[mask] = 1.0+hue[mask]
    mag = cp.abs(z)
    if z_max is None:
        z_max = cp.max(mag)
    if z_min is None:
        z_min = cp.min(mag)
    val = (mag-z_min)/(z_max-z_min)
    hsv_im = cp.transpose(cp.asarray([hue,cp.full_like(hue,0.5),val]))
    return hsv_to_rgb(hsv_im.get())

def complex_plot(z,z_min=None,z_max=None,abssq=False,**kwargs):
    plt.xlim(-2,2)
    plt.ylim(-2,2)
    return plt.imshow(to_image(z,z_min,z_max,abssq),extent=extent,interpolation='bilinear',**kwargs)
```

With that, some simple cases can be plotted.

{{< figure src="/images/qm_2d/wave_packet.png" class="center" caption="A wave packet with zero momentum is just a real-valued Gaussian distribution in two dimensions. These are complex numbers with the same phase but differing magnitude" >}}

{{< figure src="/images/qm_2d/wave_packet_mom.png" class="center" caption="A wave packet with nonzero momentum still has a magnitude that is a 2D Gaussian distribution, but the complex phase changes as a function of position at a rate proportional to the momentum. Only momentum in the X direction is shown here" >}}

{{< figure src="/images/qm_2d/wave_packet_mom_xy.png" class="center" caption="Similar to the previous, but with equal amounts of momentum in the X and Y directions." >}}

For time evolution, the code is much the same, except now potentials are a function of the 2D grid, and momentum can be in the X or Y directions.
The code for computing the time derivative can actually remain almost the same
```python
def d_dt(phi,x=x,h=1,m=1,V=0):
    return (1j*h/2/m) * gradsq(phi) - (1j/h)*V*phi
```
where the `gradsq` or $\nabla^2$ is notation generalizes the second derivative of space to higher dimensions.

More formally, $\nabla$ is a vector of derivative operators, with as many dimensions as the situation requires, often call the [gradient](https://en.wikipedia.org/wiki/Gradient) of a function.
$$
\nabla = \left(\frac{d}{dx},\frac{d}{dy},...\right)
$$
And it is understood that it behaves similar to an [operator](/post/2022/03/09/quantum-mechanics-simulation/#operators-and-convenient-notation) when "multiplying."
$$
\nabla f = \left(\frac{df}{dx},\frac{df}{dy},...\right)
$$
Applying $\nabla$ to a vector field instead of a scalar field, often called the [divergence](https://en.wikipedia.org/wiki/Divergence) is more like a dot product of $\nabla$ and the vector.
Because $\nabla$ is a vector, $\nabla^2$, sometimes called the [Laplace operator](https://en.wikipedia.org/wiki/Laplace_operator) can be thought of as
$$
\nabla^2 = \nabla\cdot\nabla = \left(\frac{d}{dx},\frac{d}{dy},...\right) = \frac{d^2}{dx^2}+\frac{d^2}{dy^2}+...
$$
where it is clear that in 1D this is the correct second derivative of position, and the intuition that this is proportional to the kinetic energy suggests the addition of a similar kinetic energy term in the y-direction is appropriate for the total kinetic energy.

With that, that the generalized multi-dimensional Schrodinger equation becomes the following.
$$
\frac{d}{dt}\psi = \frac{i}{2m}\nabla^2\psi - iV\psi
$$

The `gradsq` function implemented with the same trick in the y-direction as was previously used in the x-direction, where I've combined the central values from the two derivatives to reduce the number of matrix operations.
```python
def gradsq(phi):
    gradphi = -4*phi
    gradphi[:-1,:] += phi[1:,:]
    gradphi[1:,:] += phi[:-1,:]
    gradphi[:,:-1] += phi[:,1:]
    gradphi[:,1:] += phi[:,:-1]
    return gradphi
```

The exact same [time evolution methodology from the previous post](/post/2022/03/09/quantum-mechanics-simulation/#implementing-discrete-time-evolution) can be used with this new time derivative, since the Numpy arrays handle the generalization to 2D wavefunctions (and higher) gracefully.

### A free, stationary particle

Much like the 1D case, a stationary, localized particle spreads out in time. 
As the particle spreads into two dimensions, the reduction in magnitude everywhere to preserve the normalization is dramatic.

{{< video src="/images/qm_2d/wave_packet.mp4" class="center" width=720 height=504 >}}

### A free particle with momentum

A particle with momentum behaves as expected, and in 2D, curved wavefronts can be seen as the packet disperses. 

{{< video src="/images/qm_2d/wave_packet_mom.mp4" class="center" width=720 height=504 >}}

### A particle in a box

I almost did not include this, because its a mess, and not very intuitive to the uninitiated, but it's a mesmerizing visual.
Interference fringes can be seen in both directions, now, as the particle bounces off all four walls of the 2D box. 
Otherwise, this is quite similar to the outcome of the 1D case, getting interference patterns similar to eigenstates after the particle's location is fully scrambled.

{{< video src="/images/qm_2d/wave_packet_box.mp4" class="center" width=720 height=504 >}}

### A particle encounters a barrier

The barrier, here, is at is between $(2.5,2.75)$ and is higher potential than the classical energy of the particle, just like the 1D case.
```python
V_barrier = cp.where(cp.logical_and(xv>2.5,xv<2.75),9e-2,0)
```
The component that tunnels through can be seen, while the bulk reflects.

{{< video src="/images/qm_2d/wave_packet_barrier.mp4" class="center" width=720 height=504 >}}

### A particle in a 2D quadratic potential

A 1D quadratic potential in 2D would show dispersion in the unconstrained direction, but a 2D model lets particles bounce back and forth with the same reasoning as before.
```python
V_harmonic = 2e-2*(cp.square(xv)+cp.square(yv))
```
This example starts from the origin with a momentum in the x-direction.
{{< video src="/images/qm_2d/wave_packet_quad.mp4" class="center" width=720 height=504 >}}

Here the particle is offset, to give it some angular momentum, driving home the 2D nature of this simulation.
The "orbit" is not perfect, since I only eyeballed the radius and angle, but it makes it around a few times, unperturbed. 
Note, also, how the direction of the gradient in phase is changing with the momentum, as it should.
{{< video src="/images/qm_2d/wave_packet_quad_orbit.mp4" class="center" width=720 height=504 >}}

### Coulomb potential eigenstates

The [Coulomb potential](https://en.wikipedia.org/wiki/Electric_potential) of charged particles (and many other phenomenon) becomes interesting in two dimensions, and one can start to think of even generalizing to three dimensions to simulate a hydrogen-like atom.
Before going there, one can utilize the [complex time evolution technique]() to find eigenstates of this more interesting potential, which takes the form of an inverse square law.
$$
V(r) = \frac{-A}{r^2}
$$

The Coulomb potential is scaled here to a magnitude that makes sense for these visualizations.
```python
V_coulomb = -1e-2/np.sqrt((cp.square(xv)+cp.square(yv)))
```

Being a bit more pragmatic than before, I've put together a function to find the next lowest state given some guess containing it, and a list of states to maintain orthogonality with.
```python
def find_next_eigenstate(psi_guess, eigenstates=[], adaptive=1.0, tol=1e-10, steps=50000, dt=-1e-1j, V=V_coulomb,**kwargs):
    condition = orthogonal_to(eigenstates)
    psi_guess = condition(psi_guess)
    complex_plot(psi_guess)
    plt.show()
    plt.close()
    sim_states,eig = simulate(psi_guess,
                              dt = dt,
                              steps = steps,
                              adaptive = adaptive,
                              V = V,
                              condition = condition,
                              tol=tol,
                              **kwargs)
    complex_plot(eig)
    plt.show()
    plt.close()
    return sim_states,eig
```

This uses a more advanced version of the original `simulate` method, which includes a `tol` parameter for aborting the simulation if the difference of the two wavefunctions has a magnitude of at most `tol` at any point.
This improved `simulate` also allows for an adaptive step size which scales the step size `dt` by $-A\log_{10}\Delta$ where $\Delta$ is the same maximum magnitude of the difference between the last two time steps compared to `tol`, and $A$ is the tuning factor `adaptive`.
This lets the simulation take larger steps, proportional to the logarithm of the difference, when the difference is small, and the corresponding error of the integration will be small, converging faster to the ground state.
```python
def simulate(phi_sim, method='rk4', V=0, steps=10000, dt=1e-1, adaptive=None, condition=None, normalize=True, plot_every=None, save_every=50, tol=None):
    simulation_steps = [phi_sim.get()]
    tol_cur = 1.0
    for i in range(steps):
        if adaptive is not None:
            dt_now = -adaptive*np.log10(tol_cur)*dt if tol_cur < 1.0 else dt
        else:
            dt_now = dt
        if method == 'euler':
            phi_next = euler(phi_sim,dt_now,V=V)
        elif method == 'rk4':
            phi_next = rk4(phi_sim,dt_now,V=V)
        else:
            raise Exception(f'Unknown method {method}')
        if condition:
            phi_next = condition(phi_next)
        if normalize:
            phi_next = norm(phi_next)
        if tol is not None:
            if (tol_cur:=np.max(np.abs(phi_sim-phi_next))) < tol:
                return simulation_steps,phi_next
        phi_sim = phi_next
        if save_every is not None and (i+1) % save_every == 0:
            simulation_steps.append(phi_sim.get())
        if plot_every is not None and (i+1) % plot_every == 0:
            print(i, dt*i)
            print(tol_cur)
            complex_plot(phi_sim)
            plt.grid()
            plt.show()
            plt.close()
    return simulation_steps if tol is None else (simulation_steps,None)
```


I'll be using an initial guess with some momentum in both the x and y directions with a bit larger initial size, to ensure reasonable overlap with the lowest energy states.

{{< figure src="/images/qm_2d/coulomb_guess.png" class="center" caption="The initial guess for the Coulomb potential ground state search. There is slightly imbalanced momentum in the x-, y-directions, to break some degeneracy, and project onto a lot of eigenstates." >}}

This evolves quickly (in complex time) to the ground state, which is the 2D analog of the [$1S$ orbital](https://en.wikipedia.org/wiki/Atomic_orbital).
{{< video src="/images/qm_2d/coulomb_0.mp4" class="center" width=720 height=504 controls="on" >}}
The final state, the $1S$ orbital in 2D.
{{< figure src="/images/qm_2d/coulomb_1s.png" class="center" caption="" >}}

The next excited states are degenerate, meaning several states with the same energy, if one recalls the [angular momentum states]() possible at higher energies $2S, 2P_{x,y,z}$.
In 2D, the $S$ orbitals will be the same, and there will be $P_x$ and $P_y$ orbitals.

The first found is one of the $P$ orbitals, which is directed in the arbitrary direction of the momentum of the guess, because the guess projects more strongly on it than the other degenerate states.
Note that this takes a long (imaginary) time, because the only thing really splitting the degeneracy here is numerical error. 
{{< video src="/images/qm_2d/coulomb_1.mp4" class="center" width=720 height=504 controls="on" >}}
We find one of the $2P$ orbital analogues in 2D. Let's call it $2P_1$.
{{< figure src="/images/qm_2d/coulomb_2p1.png" class="center"  >}}

The second is the $2S$ orbital quickly falls out after removing the momentum component, meaning this guess likely projects poorly onto the remaining $2P$ orbital.
{{< video src="/images/qm_2d/coulomb_2.mp4" class="center" width=720 height=504 controls="on" >}}
This is the $2S$ orbital in 2D.
{{< figure src="/images/qm_2d/coulomb_2s.png" class="center" >}}

A very long time is required to stabilize on the final $2P$ orbital, and the simulation spends most of it stuck on what looks like the 2D analogue of a $3D$ orbital.
{{< video src="/images/qm_2d/coulomb_3.mp4" class="center" width=720 height=504 controls="on" >}}
The result is the so-called $2P_2$ orbital in 2D.
{{< figure src="/images/qm_2d/coulomb_2p2.png" class="center" >}}

There's even more degeneracy at the next energy level, and it would take a long time for this approach to converge, but in a real atom, there would be a magnetic field in addition to the electric potential, which would break this degeneracy by coupling to the orbital angular momentum of the electron.
A project for another day, perhaps.
