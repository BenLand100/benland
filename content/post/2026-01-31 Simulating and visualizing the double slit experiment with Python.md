---
title: 'Simulating and visualizing the double slit experiment with Python'
date: '2026-01-31'
categories: 
  - Math
  - Programming
  - Physics
description: A Python simulation of the double slit in two dimensions
slug: double-slit-simulation
toc: true
---

Several years ago I wrote [a post on simulation the Schrodinger Equation](/post/2022/03/09/quantum-mechanics-simulation/) that had a brief intro to Quantum Mechanics paired with a simple Python simulation and visualization.
That ended up being one of my more popular pages, despite the [follow up post with 2D visualizations](/post/2022/03/17/complex-wavefunction-visualization/) being arguably more visually appealing.
Probably down to the titles in the end -- people love a Python simulation.

The follow up post did, perhaps, get into some more interesting physics with [determination of some eigenstates of the Coulomb potential](/post/2022/03/17/complex-wavefunction-visualization/#coulomb-potential-eigenstates), but I forgot to try the [double slit](https://en.wikipedia.org/wiki/Double-slit_experiment)!
This one is particularly interesting because real world experiments can be easily done with both light and electrons, and the behavior can be easily explained by a wave nature in both cases.

## The double-slit experiment

[Wikipedia](https://en.wikipedia.org/wiki/Double-slit_experiment) covers the details well, but the general idea is that when light of wavelength $\lambda$ (or individual particles with a wavelength inversely related to their momentum) get directed towards a barrier with two narrow openings (slits) a distance $D$ apart, a pattern of bright (likely-to-observe) and dark (less-likely-to-observe) areas appear on the other side.
This pattern is consistent with the behavior of a wave of wavelength $\lambda$ self interfering after traveling through both openings, which is jarring when imagining individual quanta like photons or electrons, but how reality behaves nonetheless.

Geometrically, when far enough from the barrier, the path difference between a wave that passed through both slits would be $D \sin{\theta} \approx D \theta$.
For waves, one expects constructive interference (bright/likely spots) to be at integer multiples of wavelengths of path difference, $n \lambda$ for all integers $n$, and destructive interference between. 
That leads to a fairly simple formula for the angular spacing of bright areas,
$$
D \theta = n \lambda,
$$
which can be both experimentally verified and simulated.

## The double-slit simulation

Using [the quantum simulation code](/post/2022/03/09/quantum-mechanics-simulation/#a-full-simulation) and [2D wavefunction visualization](/post/2022/03/17/complex-wavefunction-visualization/#wave-functions-in-two-dimensions) from earlier posts, it is straightforward to design a potential and simulate firing a particle wave packet at it.
A potential is needed representing a barrier thickness $t$ with two slits of width $d$ spaced by a distance $D$.
```python
def barrier(D = 1.0, d = 0.3, t=0.2, p=2.0, V=1.0):
    V_barrier = cp.where(
        cp.logical_and(
            cp.logical_and(xv>p-t/2,xv<p+t/2),
            np.logical_or(
                np.logical_and(yv<D/2-d/2,yv>-D/2+d/2),
                np.logical_or(yv>D/2+d/2,yv<-D/2-d/2),
            )
        ), V, 0)
    return V_barrier    
```

With that, run two simulations, one with a spacing $D = 0.75$ (nominal) and one with $D=1.5$ (double) to simulate doubling the slit spacing.
```python
sim_barrier_mom1p5 = simulate(wave_packet(p_x=10),V=barrier(D=1.5),steps=5000)
sim_barrier_momp75 = simulate(wave_packet(p_x=10),V=barrier(D=.75),steps=5000)
```

Visualizing this clearly shows dark regions on the opposite side.
When the slit spacing is doubled, the angular distance between these halves (the count doubles), exactly as way theory predicts and real experiment demonstrates.
```python
def barrier_init():
    plt.xlim(-1,5)
    
animate(sim_barrier_mom1p5,init_func=barrier_init,z_max=1)
animate(sim_barrier_momp75,init_func=barrier_init,z_max=1)
```

### Nominal spacing

{{< video src="/images/qm_2d/nominal.mp4" class="center" width=720 height=504 >}}

### Double spacing

{{< video src="/images/qm_2d/double.mp4" class="center" width=720 height=504 >}}

## Back to the physics

A lot of the particle's wavefunction reflects, but there was a barrier in the way intentionally.
The part that travels through the gaps in the barrier forms the promised interference pattern on the other side.
Notably, the wavelength of this particular "particle" is around 1 in these made-up units, as can be seen visually by the distance it takes the rainbow to cycle around.
The spacing between the periodic dark regions should by the earlier equation be $\lambda/D$, which comes to $4/3$ and $2/3$ radians or about 76 and 38 degrees for the nominal and double spacing respectively.
This clearly matches the geometry of the simulation.

Visible light's wavelength is on the order of 200 nm to 800 nm, making manufacture of suitable double slits experimentally accessible without too much difficulty. 
This, along with many other tests, has allowed scientists to verify the wave nature of light.
The equivalent and unifying [de Broglie wavelength for massive particles](https://en.wikipedia.org/wiki/Matter_wave) is given by $h/p$.
The order of magnitude for these quantities in SI units are $h \approx 10^{-34}$ and $p \approx 10^{-27}$ to $10^{-25}$ for particles like neutrons or electrons, assuming some care is taken to slow them down first.
Plugging that in yields $10^{-7}$ meters ($100$ nm) to $10^{-9}$ meters (1 nm) as typical wavelengths, ranging from tricky to quite hard to manufacture from a mechanical perspective, but [verifiable for all long lived fundamental particles](https://en.wikipedia.org/wiki/Matter_wave#Applications_of_matter_waves) nonetheless.
Even higher energy particles have still shorter wavelengths, forming the basis of technologies like electron microscopes and other extremely high precision measurement devices due to the ability to construct length references at down to O(10 fm) with high energy matter waves. 

Even though this wave behavior is fundamental to all particles, such behavior isn't visible on our macroscopic scale largely because the momentum involved (order 1 in SI units) results in effective wavelengths too short to construct a suitable double slits, at O($10^{-34}$) or fewer meters. 
Even if such a device could be constructed, one would be hard pressed to observe the structure of the interference phenomenon at those tiny scales when dealing with macroscopic matter.
