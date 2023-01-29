---
title: Special Relativity, conceptually speaking
date: '2023-01-29'
categories:
  - Physics
description: My take on explaining the need for (and results of) special relativity and some of its quirks to non-physicists.
slug: special-relativity-conceptually
toc: true
---

When people learn that I have a physics degree, they typically reveal that they have _a question_ about physics they've always wanted to have answered.
Often it's something along the lines of trying to understand time dilation in relativity: the phenomenon where observers at different velocities disagree about the amount of time between events (in other words, the rate of time).
To address that question, here's a refined version of what I usually sketch out on a napkin.

## Motion at everyday speeds

{{< figure src="/images/relativity/classical.svg" class="center" caption="A classical scenario at an every-day speed $v$ where a stickperson, Alice, observes a stickperson in a spaceship, Bob, fly by (left) and visa versa (right). In the time, $\Delta t$, an object follows the trajectory of the blue arrow from floor to ceiling of the spaceship." >}}

The scenario above depicts an experiment that will soon be taken up to much higher velocities.
For now, though, I'll stick to velocities large objects in this solar system are likely to reach, where special relativity does not really come into play.
From the perspective of Alice, the object following the blue arrow is clearly observed to be moving at a higher velocity than Adam would measure, meaning it goes farther in the same observed span of time.
Critically, if both Alice and Bob have clocks, they will measure roughly the same time between the object leaving the floor and reaching the ceiling.

Tying back to the diagram, Alice sees the object travel a distance $C = \sqrt{A^2 + B^2}$ at a velocity $c = \sqrt{a^2 + v^2}$ in her reference frame, while Bob sees it go a distance $A$ at speed $a$ in his reference frame.
Newtonian physics has formalized that velocities in one reference frame can be transformed into another by adding the relative velocity of the frame like a vector, so this is all consistent.

## The fixed speed of light

Nature throws a bit of a wrench into the nice Newtonian universe with the speed of light being apparently constant.
It's not just that light is fast; it will in fact (in a vacuum) continue exactly as fast as usual regardless of how fast the observer or emitter is moving.
There is [exhaustive experimental evidence](https://math.ucr.edu/home/baez/physics/Relativity/SR/experiments.html#Tests_of_Einsteins_two_postulates) of this, using light from any number of sources, including stars with very high velocities relative to us. 

Special relativity is the theory that addresses this, and it becomes relevant when velocities near the speed of light - or the speed of light itself - come into play. 
To make this obvious, replace the object following the blue arrow with a ray of light, and make sure Alice and Bob have very accurate clocks and rulers.

## Motion approaching light speed

{{< figure src="/images/relativity/relativistic.svg" class="center" caption="A relativistic scenario with at any speed $v$ where a stickperson, Alice, observes a stickperson in a spaceship, Bob, fly by (left) and visa versa (right). In the time, $\Delta t$ for Alice and $\Delta t_0$ for Bob, a beam of light follows the trajectory of the yellow arrow from floor to ceiling of the spaceship." >}}

As in the classical scenario before, Alice still sees the light go a distance $C = \sqrt{A^2 + B^2}$ in some span of time $\Delta t$, and Bob observes the same light travel just the distance $A$ in his reference frame.
But unlike before, where Alice and Bob disagreed on the speed of the object (in an understandable way), we know Alice and Bob will measure the same speed of light, $c$, in both cases.
Since the speed of the light is the same for both, but the distances are clearly different, the simple relationship of `speed = distance / time` requires that the time observed by Bob be different, $\Delta t_0$, than that observed by Alice, $\Delta t$.

Plugging several relations in the diagram into the the distance observed by Alice, and applying a little algebra, leads to a foundational result of Special Relativity...

$$ \begin{aligned}
C &= \sqrt{A^2 + B^2} \\\\
c \\, \Delta t &= \sqrt{(c\\, \Delta t_0)^2 + (v\\, \Delta t)^2} \\\\
(c \\, \Delta t)^2 &= (c\\, \Delta t_0)^2 + (v\\, \Delta t)^2 \\\\
(c\\, \Delta t_0)^2 &= (c \\, \Delta t)^2 - (v\\, \Delta t)^2 \\\\
(\Delta t_0)^2 &= (\Delta t)^2 \left(1 - \frac{v^2}{c^2} \right) \\\\
\Delta t_0 &= \Delta t \sqrt{1 - \frac{v^2}{c^2} } \\\\
\end{aligned}$$

...that the spans of time are related by the relative velocity of the two reference frames!

### Time Dilation

Typically the $ \sqrt{1 - \frac{v^2}{c^2} } $ factor is replaced by its inverse, the Lorentz factor $\gamma$, for notational convenience.

$$
\gamma = \frac{1}{\sqrt{1 - \frac{v^2}{c^2} }}
$$

The Lorentz factor has the property that it's zero for a frame at rest with respect to an observer, and tends towards infinity as the relative velocity approaches the speed of light $c$.
With this, it's more natural to write the previous result as

$$
\Delta t = \gamma\\, \Delta t_0
$$

which means times spans, $\Delta t_0$, measured in a reference frame at rest with respect to some events will always appear to take longer in any other reference frame with a relative velocity: time dilation.

It's important to note that this effect does not require $v$ to be large, but if $v$ is not large, the effect is very small.
This allows everything we know and understand at low velocities (namely, the previous example, where that people agree on spans of time between the events) to continue to hold nominally true, while explaining the significant departures from intuition at higher velocities.

### Length Contraction

With time dilation, one gets length contraction basically for free by tacking on another experiment.
As the ship passes Alice at velocity $v$, she notes that it takes a span of time $\Delta t$ in her reference frame to pass (note the cyan bars in the diagram).
Generally speaking, Alice would ascribe a length $L = v\\, \Delta t$ to the ship.

In Bob's reference frame, the two events corresponding to the front and back of the ship passing Alice would be separated instead by the time $\Delta t_0$ at the same velocity $v$.
In that time, Alice moved past Bob's ship, which he ascribes a length $L_0 = v\\, \Delta t_0$.
By the time dilation equation, this means the two lengths are _different_:

$$
L_0 = \gamma L
$$

where the lengths in a rest reference reference frame will always measure longer than a length measured in some other reference frame with a relative velocity in the same direction as the measurement.
That last caveat is critical - contraction only occurs in the direction of the velocity difference, which allows the perpendicular lengths to be agreed upon. 

## General extensions

As experiments have shown time and time again, time dilation and length contraction are a consequence of the true nature of spacetime, as opposed to just observational effects, or quirks of light.
Mathematically, this is represented by ascribing four dimensional spacetime a [metric](https://en.wikipedia.org/wiki/Metric_space), or way of measuring distances, that describes a shape for the universe that is consistent with experiment.
That metric defines what physicists call [Minkowski spacetime](https://en.wikipedia.org/wiki/Minkowski_space), which captures all the effects of special relativity. 

Running with this idea of describing space with a metric that defines a shape, Einstein extended the special theory of relativity to include other potential shapes for spacetime, and further showed that the matter and energy within spacetime is what determines the overall shape of that spacetime.
The distortions in spacetime manifest as gravity and all of its associated phenomenon, and have explained the bulk structure of the universe to unprecedented levels of detail.
The only problem is the math gets _really, really hard_.
Perhaps a post for another day!
