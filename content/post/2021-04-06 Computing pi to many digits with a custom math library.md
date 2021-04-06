---
title: Computing π to many digits with a custom math library
date: '2021-04-06'
categories:
  - Math
  - Programming
description: Implementing the Chudnovsky algorithm to compute π to 100 digits of precision with a custom math library that represents numbers as lists of symbols.
slug: precise-pi-custom-math-lib
toc: true
---

In previous posts I implemented a math library that can do perform computations on arbitrarily large (or small) numbers.
First came [algorithms to manipulate lists of symbols as integer numbers](/post/2021/03/31/math-as-an-algorithm/), which represented signed numbers in a little endian binary format with an arbitrarily large number of bits, along with the mathematical operations of addition, subtraction, multiplication, and division.
Then this was [extended to approximate real numbers](/post/2021/04/05/real-math-as-an-algorithm/) in the form $a2^b$ where $a$ and $b$ are integers using the representation and manipulations from the earlier post.
The ultimate goal here was to implement a math library for the emulation of a simple Turing-complete programmable machine [L2](/post/2021/01/21/l2-lisp-machine-python/), but so far has only been implemented in Python using language features of L2 (except for a [teaser of L2 code for integer math](/post/2021/03/31/math-as-an-algorithm/#next-steps)).
But now that I have a custom math library capable of arbitrarily precise floating point calculations, given enough time, I might as well use it for something interesting, like calculating $\pi$.

## The quest for $\pi$

The number that relates the diameter of a circle $d$ to its circumference $C$ is $\pi$.
$$ C = \pi d $$
$\pi$ is an irrational number, meaning the position notation in any integer base is an infinite series of non-repeating digits, and there are no two integers whose ratio is $\pi$.
Practically this means there is no unit of measure, no matter how small, that can be used to measure the diameter and circumference of a circle in an integer number of units.

Because it is irrational and represented by an infinite non-repeating series, calculating $\pi$ to many digits has been a [historical pastime](https://en.wikipedia.org/wiki/Pi#History) for mathematically-minded individuals over the past three to four thousand years.
Before the 1900s, these calculations reached into the hundreds of digits of precision, which is quite a feat considering this was done by hand.
With the [aid of computing machines](https://en.wikipedia.org/wiki/Pi#Modern_quest_for_more_digits), computations of the digits of $\pi$ hit the thousands of digits.
These computations mostly used the relation $\pi = 4\tan^{-1}(1)$ and the [series expansion](https://en.wikipedia.org/wiki/Series_expansion) of the inverse tangent.
$$ \tan^{-1}(x) = \sum_{n=0}^\infty (-1)^n\frac{x^{2n+1}}{2n+1} = x - \frac{x^3}{3} + \frac{x^5}{5} - \frac{x^7}{7} + ... $$
Basically, substitute $x = 1$ into that series, and compute as many terms as you can, add them all up, and multiply by $4$ to get $\pi$. 
Because each term is smaller than the last, this converges, and you can stop computing terms when the term is less than the precision you desire.

The inverse tangent series converges very slowly, since the denominator is only linear with the number of terms.
This means one has to compute _many_ terms to get reasonable precision.
Fortunately, there are faster-converging series of a style discovered by [Ramanujan](https://en.wikipedia.org/wiki/Srinivasa_Ramanujan#Mathematical_achievements) representing the inverse of $\pi$.
Using such formulas and modern computers, calculations of $\pi$ have [topped 50 trillion](https://blog.timothymullican.com/calculating-pi-my-attempt-breaking-pi-record). 
Using my non-optimized list-math implementation, I'll aim for a hundred or so digits of $\pi$, and let the truly obsessed go for the trillions.

## Ramanujan and the Chudnovsky brothers

[Ramanujan](https://en.wikipedia.org/wiki/Srinivasa_Ramanujan) developed many formulas for computing $\pi$, and one of his most successful is given below.

$$ \frac{1}{\pi} = \frac{2\sqrt{2}}{9801} \sum_{k=0}^\infty \frac{(4k)!(1103+26390k)}{(k!)^4 396^{4k} } $$

How Ramanujan came up with this is a true mystery to me, [but it works](https://www.maa.org/sites/default/files/pdf/pubs/amm_supplements/Monthly_Reference_5.pdf), is based on [elliptic integrals](https://en.wikipedia.org/wiki/Elliptic_integral), and [a whole class of similar equations can be constructed](https://doi.org/10.1016/j.jnt.2013.04.010).
This and similar formulas were used in several record breaking $\pi$ calculations.

Basically, the series, which can be summed to an exact rational number, is first calculated to the desired precision.
Since the terms in the series shrink very fast (suppressed by a factorial to the fourth power!), precision comes quickly.
The sum is then multiplied by the irrational (as it contains $\sqrt{2}$) prefactor, which must also be computed to the desired precision, and inverted to obtain $\pi$.

The [Chudnovsky brothers](https://en.wikipedia.org/wiki/Chudnovsky_brothers) came up with [a series in the same general class](https://en.wikipedia.org/wiki/Chudnovsky_algorithm) that converges even faster, producing roughly 14 digits of precision in each term.

$$ \frac{1}{\pi} = \frac{1}{426880\sqrt{10005}} \sum_{k=0}^\infty \frac{(6k)!(13591409+545140134k)}{(3k)!(k!)^3 (-262537412640768000)^{k} } $$

This can be calculated in the same way as Ramanujan's original formula, and is the basis for the modern record-breaking $\pi$ calculations.

## Implementing the calculation

The series terms will be calculated exactly as integers in the numerator and denominator. 
This will use functions developed in previous posts to represent the constants in the calculation as integers.
```python
b_six = str_to_bin_rep('6')
b_545140134 = str_to_bin_rep('545140134')
b_13591409 = str_to_bin_rep('13591409')
b_three = str_to_bin_rep('3')
b_640320 = str_to_bin_rep('640320')
b_neg262537412640768000 = str_to_bin_rep('-262537412640768000')
```
The function to calculate the numerator and denominator for a particular term should take and return exact float representations, so some conversion from float representations to binary representations is necessary.
```python
def chudnovsky(i):
    '''Caculates terms in the series from 
       https://en.wikipedia.org/wiki/Chudnovsky_algorithm'''
    q = float_rep_to_bin_rep(i)
    
    six_q_fac = factorial_bin_rep(mul_bin_rep(b_six,q))
    poly_top = add_bin_rep(mul_bin_rep(b_545140134,q),b_13591409)
    top = mul_bin_rep(six_q_fac,poly_top)
    
    q_fac = factorial_bin_rep(q)
    q_fac_cubed = mul_bin_rep(q_fac,mul_bin_rep(q_fac,q_fac))
    three_q_fac = factorial_bin_rep(mul_bin_rep(b_three,q))
    fac_bottom = mul_bin_rep(three_q_fac,q_fac_cubed)
    pow_bottom = ipow_bin_rep(b_neg262537412640768000,q)
    bottom = mul_bin_rep_signed(fac_bottom,pow_bottom)
    
    return (top,[]),(bottom,[])
```
To calculate 100 digits of $\pi$ one needs enough bits of precision to represent 101 decimal digits.
$10^{101}$ is a number with that many digits, and $\log_{2} 10^{101}$ would give the approximate number of binary bits needed to represent it in positional notation.
Using logarithm identities, this is $\log_{10} 10^{101} / \log_{10} 2$ or $101 / \log_{10} 2 \approx 335.5$
Airing on the conservative side, this means $350$ bits should be more than enough to accurately represent 100 digits of $\pi$.
At the same time, store $10^{-100}$ as the desired tolerance for series convergence. 
```python
max_bits = str_to_bin_rep('350')
ftol = str_to_float_rep('0.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001',max_bits=max_bits)
```
Computing the series accurately is a good start, but then the irrational number $426880\sqrt{10005}$ must be computed precisely. 
Notably, typing this into Wolfram Alpha
```plaintext
42698670.6663333958177128891606596082733208840025090828008380
```
does not give enough digits to simply throw it into the calculation: the value of $\pi$ would be inaccurate past this 60 digit limit.
The solution, then, is to also calculate the square root very precisely when calculating $\pi$.
I have previously implemented an arbitrary power function that could compute $10005^{0.5}$, however this is quite slow.
An iterative method that approximates the square root of a number can be arbitrarily precise and much faster.

Given some guess $g$ for $\sqrt{a}$, a better guess $g'$ is given by:
$$ g' = \frac{g+a/g}{2} $$
When the difference between $g$ and $g'$ is less than some tolerance, the result is accurate to that tolerance. 
This can be implemented with recursion as follows.
```python
def sqrt(a,x=None,ftol=small,max_bits=bin_precision):
    if x is None:
        x = a
    x_new = div_float_rep(add_float_rep(x,div_float_rep(a,x,max_bits=max_bits)),two,max_bits=max_bits)
    if lt(abs(sub(x,x_new)),ftol):
        return x_new
    else:
        return sqrt(a,x=x_new,ftol=ftol,max_bits=max_bits)
```
Then the quantity $426880\sqrt{10005}$ can be calculated to the desired 100 digit (350 bit) precision.
```python
root_10005_426880 = mul_float_rep(from_string('426880'),sqrt(from_string('10005'),ftol=very_small,max_bits=max_bits))
print(float_rep_to_str(root_10005_426880,max_digits=str_to_bin_rep('100')))
```
```plaintext
42698670.6663333958177128891606596082733208840025090828008380071788526051574575942163017999114556686
```
This can be compared to the Wolfram Alpha result above, where agreement up to the precision Alpha provides can be seen.

Now the $\pi$ calculation can be done.
I've used the tolerance and precision of the rest of the math library as defaults, assuming a desired tolerance and precision will be set later.
This method also calculates $\pi$ at each term of the series and compares to tolerance, which is strictly speaking not necessary, but interesting to see in this test.
In a serious record-breaking computation, the number of desired terms would be pre-calculated from the 14 digits of precision given by each term.
```python
def calc_pi(ftol=small,max_bits=bin_precision):
    chudnovsky_sum = zero
    i = zero
    last_pi = zero
    while True:
        top,bottom = chudnovsky(i)
        term = div_float_rep(top,bottom,max_bits=max_bits)
        chudnovsky_sum = add_float_rep(chudnovsky_sum,term)
        pi = div_float_rep(root_10005_426880,chudnovsky_sum,max_bits=max_bits)
        print('pi_est(%s)'%to_string(i),float_rep_to_str(pi,max_digits=str_to_bin_rep('100')))
        if lt(abs(sub(pi,last_pi)),ftol):
            return pi
        last_pi = pi
        i = add_float_rep(i,one)
```

## Computing $\pi$

Finally $\pi$ can be computed.
```python
pi = calc_pi(ftol=ftol,max_bits=max_bits)
float_rep_to_str(pi,max_digits=str_to_bin_rep('100'))
```
```plaintext
pi_est(0) 3.141592653589734207668453591578298340762233260915706590894145498737666209401659108066117347469689758
pi_est(1) 3.141592653589793238462643383587350688475866345996374315654905806801301450565203591105830910219290929
pi_est(2) 3.141592653589793238462643383279502884197167678854846287912727790370642977335176958726922911495373797
pi_est(3) 3.141592653589793238462643383279502884197169399375105820984947408020662452789717346364103622321101908
pi_est(4) 3.141592653589793238462643383279502884197169399375105820974944592307816346694690247717268165239156011
pi_est(5) 3.141592653589793238462643383279502884197169399375105820974944592307816406286208998628395732194831867
pi_est(6) 3.141592653589793238462643383279502884197169399375105820974944592307816406286208998628034825342117066
pi_est(7) 3.141592653589793238462643383279502884197169399375105820974944592307816406286208998628034825342117068
pi_est(8) 3.141592653589793238462643383279502884197169399375105820974944592307816406286208998628034825342117068
Final result:
3.141592653589793238462643383279502884197169399375105820974944592307816406286208998628034825342117068
```
Compare this to your [favorite resource for $\pi$ digits](http://www.math.com/tables/constants/pi.htm) to see that it is correct up to rounding the last digit.
