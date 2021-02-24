---
title: Implementing exponentiation without a standard math library
date: '2021-02-24'
categories:
  - Programming
  - Math
slug: power-without-math-lib
toc: true
---

Exponentiation, or $x^y$, is typically provided by a standard math library on the system you are using as the function `pow(x,y)`, or similar.
However, if you are programming on some embedded system without standard libraries, or have some externally imposed constraints preventing you from using standard math libraries, it is possible to implement it yourself.
Of course, you could look up existing implementations, copy them, and call it a day, but where's the fun in that?

## Positive integer powers

This is the easiest case, where the $y$ in $x^y$ is a (positive!) integer, and exponentiation is just repeated multiplication of $x$ by itself $y$ times, as one learns somewhere around kindergarten.
I'll call this `ipow` to distinguish it from the more general case.
This can be implemented with recursion:
```python
def ipow(x,y):
    if y == 0:
        return 1
    return x*ipow(x,y-1)
```
It can also be implemented with a for loop:
```python
def ipow(x,y):
    res = 1
    for i in range(y):
        res = res*x
    return res
```
It is also possible to make these support negative integers (repeated division), but that won't be necessary in the following sections.

## Arbitrary powers

If the $y$ in $x^y$ is not an integer, things get a bit trickier.
It is always possible to factor out any integer part $a$ and fractional part $b$ of $y$ using the relationships:
$$ y = a + b $$
$$ x^y = x^a x^b $$
where $x^a$ could be calculated with repeated multiplication, but leaving $x^b$ no less of a problem.
A method for computing this arbitrary exponentiation is required.

### Series expansion

The typical next step to computing some complicated function is to use a [series expansion](https://en.wikipedia.org/wiki/Series_expansion) around a particular point.
So defining general exponentiation as 
$$ f(x,y) = x^y $$
the function $f(x,y)$ could be expanded around, for instance, point $(0,0)$ to arrive at a simple polynomial expression for the function.
This is a pain, because $f(x,y)$ is a function of two variables, which means a lot of partial derivatives will be required to arrive at a series expansion.

A common trick is to transform expressions into common forms for which series expansions are already tabulated.
Consider the following manipulation:
$$ f(x,y) = x^y = \left({e^{\log x}}\right)^y =  e^{y \log x} $$
Exponentiation with base $e$, often the `exp` function, has a well known series expansion:
$$ e^z = \sum_{n=0}^{\infty} \frac{z^n}{n!} $$
where $n!$ is the factorial of $n$:
$$ n! = \prod_{m=1}^n m $$
So after calculating $z = y \log x$, this quantity could be plugged into the series expansion for $e^z$ to get the value $x^y$.
This leaves only the natural logarithm $\log x$ to be calculated, which has many series expansions, including:
$$ \log (1+x) = \sum_{n=1}^\infty (-1)^{n+1} \frac{x^n}{n}$$
and a faster-converging series based on the [inverse hyperbolic tangent](https://en.wikipedia.org/wiki/Inverse_hyperbolic_functions#Inverse_hyperbolic_tangent):
$$ \log x = 2 \tanh^{-1}\left(\frac{1-x}{1+x}\right) = \sum_{n=0}^\infty \frac{2}{2n+1} \left( \frac{1-x}{1+x} \right)^{2n+1} $$

Note that these series sum an infinite number of terms, however (after a point) each term is smaller than the last, so it is sufficient to compute enough of these terms until they fall below some maximum error threshold, then sum them all up.

### exp

To compute the series expansion of `exp` first implement a `factorial` function:
```python
def factorial(x):
    if x == 0:
        return 1
    return x*factorial(x-1)
```
or with loops instead of recursion:
```python
def factorial(x):
    res = 1
    for i in range(1,x+1):
        res = res*i
    return res
```

There is then one important observation to be made before implementing `exp`: the terms oscillate between positive and negative values when the input is negative, because even powers of negative numbers are positive, and odd powers are negative. 
For large negative inputs, this can lead to considerable computational error, because these large oscillating values are expected to cancel each other out, and floating point numbers don't have enough precision to represent the cancellations accurately.
Specifically, consider:
$$ e^{-50} = 1 - 50 + \frac{50^2}{2} - \frac{50^3}{6} + \frac{50^4}{24} + ... $$
Only at the 133rd term $\frac{50^{133}}{133!}$ does the factorial catch up with the exponential, causing the term to drop below 1, and $133! \approx 1.48\times10^{226}$. 
Before this, terms such as the 50th exceed $10^{20}$, which has more digits than can be accurately represented in a 64bit floating point number, causing large errors to accumulate when the oscillating terms fail to cancel. To avoid this problem, the relation
$$ e^{-z} = \frac{1}{e^z} $$
can be used to instead calculate the exponential of a positive number, where large numbers still exist, but they grow instead of cancel, which results in far less accumulated error.

This results in the following implementation, where the `ftol` parameter sets the maximum value the next term can take before the calculation terminates.
Note the use of `ipow` from earlier to compute the integer powers.
```python
def exp(z,ftol=1e-20):
    if (z < 0):
        return 1/exp(-z,ftol=ftol)
    res = 1
    i = 1
    while True:
        term = ipow(z,i)/factorial(i)
        res = res+term
        if term < ftol:
            break
        i = i+1
    return res
```

### log

The natural logarithm function `log` can be approached the same way as `exp` using the series expansions given earlier.
The only major issue here is that the series terms for `log` shrink much more slowly than `exp` (suppressed by a factorial), which means many more terms must be computed to get an accurate result for large input values.
There are some shortcuts that can be taken to transform logarithms of large numbers into logarithms of smaller numbers, not unlike the trick used to transform `exp` of negative numbers into `exp` of positive numbers.

Consider that any number $x$ can be represented as $pq^r$ where $r$ is an integer and $p$ and $q$ are arbitrary values, then the following relations hold
$$ \log x = \log(pq^r) = \log p + r \log q $$
Therefore, a large $x$ can have $r$ factors of $q$ removed, leaving $p$, and only $\log p$ and $\log q$ need be calculated to find $\log x$.
$q$ can be chosen such that both $q$ and $p$ are small. 
In the following implementation, I've arbitrary chosen a default $q = 3$ because `log(3)` and any smaller value is fast to compute with this series expansion.
```python
def log(x,q=3,ftol=1e-20):
    if x > q:
        r = 0
        while x > q:
            x = x/q
            r = r+1
        return log(x,q=q,ftol=ftol)+r*log(q,q=q,ftol=ftol)
    else:
        ratio = (x-1)/(x+1)
        res = 0
        i = 1
        while True:
            term = 2*ipow(ratio,i)/i
            res = res+term
            if (term if term>0 else -term) < ftol:
                break
            i = i+2
        return res
```

### pow

With series expansions of `exp` and `log` available, it is straightforward to implement `pow(x,y)` using the relation from earlier
$$ x^y = e^{y\log x} $$
```python
def pow(x,y):
    return exp(y*log(x))
```
