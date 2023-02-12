---
title: 'Low level concepts in quantum computing'
date: '2023-02-12'
categories: 
  - Math
  - Physics
description: A deep dive into quantum computing and how it compares to classical computing.
slug: quantum-computing-concepts
toc: true
---

This post will try to give a grounded conceptual (with a side of mathematical) understanding of quantum computing by comparing it to classical computing.
This can be a bit tricky, since robust quantum computers are still a nascent technology, but I'll stick to the low level concepts here instead of getting into the esoteric science that is _programming_ quantum computers.
Primarily I want to motivate why quantum computing is fundamentally different from classical computing, and how it is the same.

## Representation of information

Classical bits, like those used in your computer, can be in one of two states: high ($1$) or low ($0$).
These are physically realized as toggle switches for electrical current (specifically [flip-flops](https://en.wikipedia.org/wiki/Flip-flop_(electronics))), which are literally in an on or off state.
The possibility of exactly two discrete states per bit means that collections of $N$ bits are able to represent $2^N$ discrete configurations.
Operations can be represented as functions that map from one configuration of bits to another.
Algorithms can be constructed as collections of operations in particular orders.
Around this, all of modern computing has developed.

### Single Qubits

Quantum bits -- qubits -- are two state quantum systems. 
These are physically realized in many ways, and two common examples are the spin of an electron or polarization of a photon. 
The difference between a classical bit with two classical states and a qubit with two quantum states is that quantum mechanics is probabilistic, and describing how a two state system behaves physically requires a careful accounting of all possibilities. 
All possibilities includes any arbitrary mixture of the possible outcomes, which means observing a qubit in one of its two states.
Observing it in a particular _basis state_, either $\ket{0}$ or $\ket{1}$, could happen all of the time, none of the the time, or some mixture.
Rigorous physical and mathematical treatment of an arbitrary two-state system, $\ket{\psi}$, reveals that the two states can be thought of as being mixed together with complex coefficients:

$$ \ket{\psi} = C_0 \ket{0} + C_1 \ket{1} $$

Classically, that is _when the state is measured_, $C_n$ is found to be either $1$ or $0$ in any particular instance.
On the other hand, as long as the two state system is left isolated or carefully controlled, it will evolve into very interesting combinations of $C_0$ or $C_1$ with real and imaginary components. 

The physical interpretation of this formalism is that magnitude squared of the complex components $C_n$ is interpreted as a probability to be measured in the particular basis state $\ket{n}$.
So, by performing many experiments that result in the same $\ket{\psi}$ and measuring the distributions of $\ket{0}$ to $\ket{1}$, the relative magnitudes of $C_0$ and $C_1$ can be determined, and there are similar operations to determine the relative phase.

#### Some mathematical formalism

Mathematicians would say this combination of two basis states spans a [complex Hilbert space](https://en.wikipedia.org/wiki/Hilbert_space#Quantum_mechanics), meaning that the two states are like two axes in a world where the coordinate axes are complex numbers, and the state is a point $(C_0,C_1)$ in that 2D space.
This is a form of _abstract vector space_, and the the arbitrary state $\ket{\psi}$ is often called a state vector in physics for this reason.
Most of the intuition from normal vectors in linear algebra will carry over to state vectors.
Along these lines, one could write $\ket{\psi}$ as a column vector. $  \newcommand\vector[1]{\begin{bmatrix}#1\end{bmatrix}} $

$$ \ket{\psi} = \vector{C_0\\\\C_1} $$

The probabilistic interpretation of the magnitude squared of the components implies that the sum of the magnitudes squared of all $C_n$, or the magnitude of the state vector, should be $1$.
Thinking about this from the perspective of an inner product (or dot product), which computes the magnitude squared of all components of a vector, this means something like the probability of a state to be itself is 100%.

This idea of a state being another state in abstract vector spaces is captured by a more rigorous definition of the inner (or dot product, from linear algebra). 
The inner product of the state with itself is historically written as :

$$\braket{\psi|\psi}$$

This introduces the idea of a conjugate vector $\bra{\psi}$ which flips the sign of the imaginary part of all the complex numbers (flips across the real axis -- conjugation is denoted with $^*\\,$).

$$ \bra{\psi} = C_0^* \bra{0} + C_1^* \bra{1} $$

A conjugate vector like this would be written out as a row vector instead of a column vector

$$ \bra{\psi} = \vector{C_0^* & C_1^*} $$

and normal matrix multiplication would provide the result.

$$\braket{\psi|\psi} =   \vector{C_0^* & C_1^*}  \cdot \vector{C_0 \\\\ C_1} = |C_0|^2 + |C_1|^2 $$


In the notation of physics one needs to understand that the two basis states are distinct in the sense that their inner product is zero, while the inner product of a labeled state with itself is unity. All other usual linear algebra rules apply.

$$ 
\begin{aligned}
\braket{\psi|\psi} &= (C_0^* \bra{0} + C_1^* \bra{1})(C_0 \ket{0} + C_1 \ket{1}) \\\\
&= C_0^* C_0 \braket{0|0} + C_0^* C_1 \braket{0|1} + C_1^* C_0 \braket{1|0} + C_1^* C_1 \braket{1|1} \\\\
&= C_0^* C_0 + C_1^* C_1 \\\\
&= |C_0|^2 + |C_1|^2 \\\\
\end{aligned}
 $$

So, probability of the particle being in its own state $\braket{\psi|\psi}$ being 1 means the coefficients are subject to the constraint:

$$ |C_0|^2 + |C_1|^2 = 1 $$

which puts decent constraints on the magnitudes of the two coefficients, such that one fully determines the other, but does not strongly constrain the phase.

#### Back to the implications

{{<figure src="/images/qc/bloch_sphere.svg" class="right" caption="The Bloch sphere represents the space of possible states for a 2-state quantum mechanical system, paramaterized by $\theta$ and $\phi$ for the generic state $\ket{\psi}$." >}}

Typically only the relative phase of the two states is physically observable, leaving the relative phase and relative magnitude as the only free parameters here, even though a state is represented by two complex numbers (four real numbers).
Often these two remaining parameters are thought of as the surface of [a sphere](https://en.wikipedia.org/wiki/Bloch_sphere), where the latitude is the relative magnitude (poles being purely one or the other state) and the relative angle being the longitude.

In simpler terms, this means one qubit can represent a point on the surface of a sphere, which is clearly quite a bit more information than simply "on" or "off".

### Multiple Qubits

The true power comes when one considers collections of two-state systems, or collections of qubits called quantum registers.
Separately, $N$ qubits are $N$ two-state systems, but considered together (which brings some serious engineering challenges) they are much more, because any measurement outcome now has $2^N$ possibilities, and the probabilities of each must be correctly accounted for.

For a two qubit system, we get combinations of basis states from both qubits like $\ket{0_0}\ket{0_1}$ representing the zero state of qubit 0 and qubit 1, which is often written as just $\ket{00}$ letting the index of the digit define the qubit the digit is for.
All the possible outcomes of a 2-qubit system are:

$$ \ket{00}, \ket{01}, \ket{10}, \ket{11} $$

The treatment above finds the 2-qubit 4-state system has three free relative phases and three freely determined magnitudes, meaning six free parameters. 
For 3-qubits we have: 

$$ \ket{000}, \ket{001}, \ket{010}, \ket{011}, \ket{100}, \ket{101}, \ket{110}, \ket{111}$$ 

7 relative angles and 7 magnitudes; 14 parameters. This grows exponentially with the number of qubits!

The salient point here is that for quantum registers, the number of free, real, parameters is $2(2^N-1)$ for $N$ qubits. 
This is often misquoted (and I will below) as $2^{N+1}$, as it is approximately that for large $N$, and because it takes $2^N$ complex numbers (which are inherently two-dimensional, with a real and imaginary part) to specify a point in the $2^N$ dimensional complex Hilbert space of a $N$-qubit register. 

## Extreme information processing density

The above means an $N$-qubit quantum register is represented by a state of approximately $2^{N+1}$ real-valued parameters while classical registers can only represent one of $2^M$ unique values for $M$ bits. 

While each operation on classical register can result in one of $2^M$ results, contingent on some algorithm with $2^M$ possible inputs, an operation on a quantum register can result in $2^{N+1}$ real values contingent on some algorithm with $2^{N+1}$ real value inputs. This means a 32-qubit quantum computer could - in theory - operate on around eight billion real numbers at once - a feat that your average 32-bit classical computer would require around eight billion operations to accomplish, assuming those real numbers could be approximated by 32-bit floats.
Pushing this to larger numbers of qubits -- say, 64 -- reveals computational power unparalleled: nearly 10^20 state values operated on, which would take a modern 64-bit processor core thousands of years to simulate, if the thousand exabytes of RAM needed to hold the state existed. 

The idea of operation on large batches of real values at once is what makes quantum computing attractive. This massive parallelism has inspired [algorithms to factor very large numbers quickly](https://en.wikipedia.org/wiki/Shor%27s_algorithmquian), there are clear [applications to neural networks](https://en.wikipedia.org/wiki/Quantum_neural_network), and even more mundane things like [rapidly multiplying matrices](https://doi.org/10.1038/srep24910) can be done.
However, while one can imagine how a classical switch might be turned off and on to represent a bit used in computations, operating on a qubit - or quantum register - is far less easy to imagine.
With that in mind, I'll try to show here a comparison of foundational quantum computing concepts to those that underpin modern classical computers.

## Basic architecture

Modern computers are based on tiny electrically operated switches, called transistors.
These devices exploit the fact that the conductivity of interfaces of certain materials known as semiconductors can be changed by orders of magnitude with application of electrical potential in the right place, allowing them to conduct or not depending on whether some upstream switch is conducting or not.
Combining transistors with resistors allows for the construction of [logical gates](http://hyperphysics.phy-astr.gsu.edu/hbase/Electronic/trangate.html) which have well defined rules for how the output behaves given some input.
These rules are simple maps from a discrete set of input configurations to a discrete set of output configurations, called a logic table.

{{<figure src="/images/qc/full-adder.png" class="right" caption="A full adder can be chained together into a circuit to add registers of classical bits representing integer numbers.  From top to bottom, XOR, AND, and OR gates are used." >}}

Combinations of logical gates are used to implement particular operations on collections of bits, like this full adder in the circuit diagram to the right.
Each symbol refers to a particular logic table to control the output, and the lines refer to how the tables outputs are used as inputs to other tables.
By building up more and more complicated circuits, a library of common operations is created, from which any other operation can be efficiently constructed.
Computer programs are then written to choose the order in which these operations are applied and to which collections of bits, to implement classical algorithms that allow your computer to do interesting things.
Given enough time and bits, these algorithms can solve [almost any problem](https://en.wikipedia.org/wiki/Halting_problem).

### Quantum computation

Quantum computers instead use physical phenomenon like the spin of an electron as their base unit of information.
These spins can be manipulated with electromagnetic fields (external or other qubits) to perform operations, or be kept in isolation to store quantum information.
The exact details of moving quantum information around and holding it for long timescales are the limiting factor for practical quantum computing in 2023. 

The physical idea goes like this ---
1. External stimuli can be used to put a system of qubits into some known state
2. A series of operations can do something useful, like perform some calculation.
3. Finally, the result can be measured. 

By repeatedly performing the same quantum calculation over and over and measuring the result, the configuration of the free parameters at the end (the result of the calculation) can be determined. 

I've said that physical qubits can be manipulated with physical interactions like magnetic fields, but exactly how this translates into computations merits some further explanation.
From a computational perspective, we have the following analogy.
* **Classical** A circuit represents some operation by mapping a particular configuration of bits to some other configuration of bits according to the rules of that operation.
* **Quantum** A contrived physical situation represents some operation by causing a physical state to change in a certain way into another physical state according to the rules of that operation.

In other words, an operation is something that causes an arbitrary state $\ket{\psi_0}$ to change into some other state $\ket{\psi_1}$.
This is accomplished by arranging the physical environment (turning on a magnetic field, in a particular direction, for a particular time, for instance) the qubits are in such that the normal quantum mechanical evolution of the state proceeds in a certain desired way.
To double down, compare this to arranging transistors and resistors in a certain way such that the flow of electrical current goes in a certain desired way. 
Both scinareos can be used to compute, but the quantum one has access to a much larger space for operations.

### Quantum operations

Describing how to change an arbitrary state $\ket{\psi}$ into another state means understanding how states change in the first place.
Borrowing from the mathematical formalism earlier, we know that any state can be described as a vector of complex coefficients with unit magnitude.
It is known that the most general type of operation that transforms a unit complex vector into another complex unit vector is a complex square matrix with the unitary property.
More specifically, if the state vector has $N$ components, then an arbitrary operation can be represented by the operator $U$ which is an $N \times N$ matrix that preserves the length of any vector it operates on.

Transformation of a state by an operator $U$ is written like
$$
\ket{\psi_1} = U\ket{\psi_0}
$$

It is important to note that not all possible operators $U$ are easy to implement physically, but there are a collection of operations that are sufficient to construct many useful algorithms.
This is analogous to how there are many possible classical logic tables, but only a finite set of simple ones (AND, OR, NOT, XOR, etc) are necessary to perform any calculation.

To make this a bit more concrete, consider the quantum equivalent of the classical NOT gate, which inverts the inputs, often called $X$.
For a single qubit, $X$ takes the matrix form
$$
X = \vector{0&1\\\\1&0}
$$
meaning that it swaps the coefficients of the two states, much like NOT swaps the logic level of the input.
$$
\vector{0\\\\1} = \vector{0&1\\\\1&0} \cdot \vector{1\\\\0}
$$
It is called the $X$ gate, because it represents a 180-degree rotation around the X-axis of a Bloch sphere, which can be physically realized by applying a certain frequency of electromagnetic radiation for a certain amount of time to the qubit in question.

#### Deep into the math of Quantum Mechanics

Ultimately the dynamics of any quantum system are [governed by the Schrodinger equation](/post/2022/03/09/quantum-mechanics-simulation/#time-evolution), and this is no exception.
The unitary operators here can be derived from a Schrodinger equation for a [particular Hamiltonian and potential](/post/2022/03/09/quantum-mechanics-simulation/#specifics-a-single-particle-hamiltonian), and often that is the more convenient perspective to consider when trying to physically realize quantum logic gates.

Diving into [the math of quantum mechanics](/post/2022/03/09/quantum-mechanics-simulation/#not-a-crash-course-introduction-to-quantum-mechanics), but this time with matrix instead of wave mechanics, one can design a Hamiltonian operator on the state vector $H$ such that the energy of the state is given by
$$
E = \bra{\psi}H\ket{\psi}
$$
Then the solution to the Schrodinger equation, 
$$
\frac{d}{dt} \ket{\psi} = -iH\ket{\psi} 
$$
which governs time evolution, is 
$$
\ket{\psi(t)} =  e^{-i H t} \ket{\psi(0)}
$$
which is manifestly true, as long as you don't think too hard about what $e$ raised to the power of a complex matrix is!

As it turns out, if $\ket{\psi(0)}$ is an eigenstate of the Hamiltonian, this is the usual result that energy eigenstates only change phase in time. 
In a two-state system, if both basis states are eigenstates have the same energy, both states will stay in phase as time moves on, and this would correspond to an identity gate $I$ in the quantum logic gate world.
$$
I = e^{-iEt}\vector{1 & 0 \\\\ 0 & 1}
$$
If both basis states are eigenstates with different energies, with separation $\Delta E$, this would correspond to a phase shift gate, $P$ where the amount of phase shift would depend on the amount of evolution time.
$$
P = e^{-iEt}\vector{1 & 0 \\\\ 0 & e^{-i\Delta E t}}
$$
Recall that in both cases, the overall phase $e^{-iEt}$ is not observable.

When $\ket{\psi(0)}$ is not an eigenstate, things are a bit more interesting, and the unitary matrix $U$ representing evolution under the Hamiltonian $H$ for some time $t$ is given by
$$
U = e^{-i H t}
$$
which can be understood as the series expansion of the exponential function to be
$$
U = \sum_{k=0}^\infty \frac{(-it)^k}{k!} H^k
$$
with a matrix raised to a power meaning repeated application of that matrix.

In this way, the unitary operators $U$ that describe quantum logic gates can be assumed to be given by time evolution of the Schrodinger equation for particular physical scinareos.

### Universal Computation

{{<figure src="/images/qc/quantum-full-adder.png" class="right" caption="A quantum full adder can be chained together into a circuit to add registers of quantum bits representing superpositions of integer numbers. Triffoli and CNOT gates are used." >}}

A set of operations, often called [quantum logic gates](https://en.wikipedia.org/wiki/Quantum_logic_gate), are known to exist, which can construct any (with few caveats) quantum operation. 
The list is not huge: $X$, $Y$, $Z$, $H$, $P$, $T$, $CNOT$, $CZ$, $SWAP$, and Toffoli ($CCNOT$) are common, and physical implementations exist.
This allows quantum circuits, like the quantum full adder to the right, to be constructed to do useful computations.
Like the classical scenario, these can be built up into vastly complex operations in aggregate.

## Practical Quantum Computing

In much the same way that you would not write a computer program by selecting transistors and resistors and wiring them into logic gates to build up your program, quantum computing nominally does not involve thinking about the detailed construction of the quantum gates.
There would be some "quantum compiler" which translates or compiles a language based on quantum concepts into a plan for applying operations (quantum gates) to particular quantum registers. 
There are Python packages like [Qiskit](https://qiskit.org/) which even supports targeting backends with different "instruction sets" (quantum gates) available.
Indeed "machine code" for a quantum computer like [QASM](https://www.quantum-inspire.com/kbase/cqasm/) has existed for a while, and can describe any quantum algorithm as long as the hardware implements a universal set of gates.

In this way, a quantum computer could be used similar to a modern classical computer, in a way that leverages a finite set of pre-engineered operations from which any arbitrary quantum program could be constructed.
That's the theory, anyway, and offerings like [IBM Quantum](https://quantum-computing.ibm.com/) are well on their way to commercializing it!
