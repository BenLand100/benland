---
title: 'Several ways to "add two number strings"'
date: '2024-09-29'
categories: 
  - Math
  - Programming
description: 'Too many solutions to the question of how to add two very big numbers represented as strings.'
slug: add-two-number-strings
toc: true
---

I was presented with an anecdote from a guy doing software development job interviews that went like this:
```plaintext
   Interviewer: Show me how you would add two big numbers represented as strings?
   Candidate:   How about `adder = lambda a,b: return int(a)+int(b)`?
   Interviewer: No, the numbers are too big `int(a)` would fail.
   Candidate:   ...
```
First off, Python is a bit unique among modern languages in that it does support integers of arbitrary size out of the box with no special fiddling.
It generally uses native size integers but transparently supports integers as large as will fit in the system's memory, and has since at least Python 2.5.

Here's python computing $64255^{543}$ (random keys I mashed, not a special number), which is a $\log_2(64255^{543}) \approx 8673$ bit number -- far larger than the largest integer type native to processors.
```plaintext
Python 3.12.6 (main, Sep 19 2024, 17:57:03) [GCC 13.3.1 20240614] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> 64255**543
4936985627220137949540777218435543934016450539709599796073237485388647886140042460943956168156327193527801172010356321878196470009164024456477230185022554590896979881690057535890347271627467171687665374057730169706992266613561753552359128928629359337422158239499898550956911439147214374705701142380325454868900270236768812832155813645392490139489630532319977546849718826884574327167006571357630124873943721969558339148803323165054980465157056215939374889113697188452542858122260448675572296757337449713004810818572054658377456090790783221107647505609355195088676156321916080005623791963078897546227918580264317119206231259093940260373542774308066319468789253000517768754086865161351270474087499686647149310503500734415665125378267877746498810321196472158846593515559798130269780601526019120914346637292433348083704000434101410704026507107134139790392304284383866926571471351586589389303589452197623345360465076763152858642046360170337755077822019349051482401979723261052777446095527940915045146471312166037121845033760467616327270768294614488579156224882171780533883795888268157360433598426268215046986528221165683986962673560578922138895636776346252942610066088810901104095721489420455785648192581951727952978320740902457941643774635634023650979548248939841185591324890520194761396241789106795886650758394574097179145283957857541004642261776468652767745882769963301704405760724859010511426021519422917035778386101096768811561540304151596245187082890547722773341819958359765830592881770987485564818066051489607579291179311339829971966301188351072530502862641955422659187188495603975210435811858457709949002278140393892930918189091358349872842560796262223967780638185203132646120676600799430342410846874547149304138037176091374683173271469696217952219976925708278315887913974006673382663020952980313939527439829175835400057333082629001378418431657391170095192141206512078293206512868242579608725917756699846597788210601216449894116776860816275248643038932954039273187682204304168219493387183154585730325665413373514559204983659959883206044247312570804292198116412737704076864611382518679773065953392266935503022116295652494255143520982271436370062843933469559906189730449220581730953321199229389783133061332832855158892781797308874098196295579494990884642718475350118008383626339880810547559783974482438371330932348597162672511901978394107998301752561373291603019728513427475703084381271451598828558655223838788505810256954037576667781616619918268218022522803742889796993853337615474347747390614170120890006582432923807239896244096642559022009268808640174333041610865171165689613275162628269754350185394287109375
```
There is a default limit to the amount of data `int()` will process (around 4.3k characters, typically), but this is a soft limit and is easy to change with a system wide setting, making this a pretty poor hill for an interviewer to die on.

## ~~A baseline~~ An Enterprise™ solution

Of course, the question was raised of how others would have answered.
If I were to be charitable, I might extrapolate this question to one of how to add two number strings without using `int()`.
So, I whipped up the following --
```python
string_to_int = {str(i):i for i in range(10)}

def enterprise_add(ns1, ns2):
    '''
        Adds two numbers stored as strings per the business requirements.
        Does not return the result because that was out of scope.
    '''
    # make ns1 the longer one to simplify logic for more efficient code review
    if len(ns1) < len(ns2): 
        enterprise_temp = ns1
        ns1 = ns2
        ns2 = enterprise_temp
    # reverse ns1 and ns2 to confuse the jr devs
    ns1 = list(reversed(ns1))
    ns2 = list(reversed(ns2))
    # accumulate the result by place value
    result = []
    carry = False
    for i in range(len(ns1)):
        # simple math, made harder for profits
        intermediate  = 1 if carry else 0 
        intermediate += string_to_int[ns1[i]] 
        intermediate += string_to_int[ns2[i]] if i < len(ns2) else 0
        # i'll just make another dictionary and demand more pay if str is off limits
        enterprise_intermediate = str(intermediate) 
        # most people pretend to understand whats going on here
        result.append(enterprise_intermediate[-1])
        carry = len(enterprise_intermediate) > 1
    result = ''.join(list(reversed(result)))
```
-- which is a standard bit of code (with some added humor) that leverages the fact that we don't need to know how to convert _all_ integer strings to integers, and really only need to know how to convert _some_ strings. Specifically, the single digits, encoded in the `string_to_int` dict are mapped to their integer values for addition.
If the use of `str()` bothers you when `int()` is forbidden, I note in the comments that I could easily replace it with yet another map, or hardcode `string_to_int` altogether.

## A more advanced approach

Why not take it further? Maybe what the interviewer meant was "add two number strings without using math" in which case my solution above, which simply adds the integer representations of the place values, is no good!
To "avoid math" altogether we can instead [treat math as a logical problem](/post/2021/03/31/math-as-an-algorithm/) and just reason out the result.
For that, I can just map all possible digit combinations to their results and keep track of the carry as before (`base10_adder`), but without utilizing Python's mathematical operators.

```python
digits = {0:'0',1:'1',2:'2',3:'3',4:'4',5:'5',6:'6',7:'7',8:'8',9:'9'}
base10_carry = lambda x: (digits[x if x in digits else x-10], x not in digits)
base10_adder = {
    (digits[i],digits[j],cz):base10_carry(i+j+ci) 
    for i in range(10) for j in range(10) for ci,cz in enumerate([False,True])
}

def enterprise_add_v2(ns1, ns2):
    '''
        Adds two numbers stored as strings per the business requirements.
        Does not return the result because that was out of scope.
    '''
    # reverse ns1 and ns2 to confuse the jr devs
    ns1 = list(reversed(ns1))
    ns2 = list(reversed(ns2))
    # accumulate the result by place value
    result = []
    carry = False
    for i in range(max(len(ns1),len(ns2))):
        # simple math, made harder for profits
        intermediate, carry = base10_adder[(
            ns1[i] if i < len(ns1) else '0',
            ns2[i] if i < len(ns2) else '0',
            carry
        )]
        result.append(intermediate)
    result = ''.join(list(reversed(result)))
```

This is cheating a little because in the bootstrap of `base10_adder` I very clearly add the `i+j+ci` values, but one can handwave that again, this dictionary could be hardcoded.

## A glorious math-free approach

Hardcoding sucks for the person that has to do it, however, so a better solution might be needed. 
Since there are 10 possible digits and addition is a binary operation, there are in principle $10^2 = 100$ elements to hardcode.
However, a place value adder really has three inputs, with the carry, making 200 entries one would have to manually enter.
Not the worst, but I wasn't going to do it myself.

### `base10_adder` math-free bootstrap
Instead, lets bootstrap the `base10_adder` from the list of string digits I typed out for testing --
```python
digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'] # would work for any base
# The possible results of adding two digits, with carry when there is overflow
carry_digits = [(d,False) for d in digits] # single digits
carry_digits.extend([(d,True) for d in digits]) # overflow extension

base10_adder = {} # maps tuples of add-with-carry inputs to their outputs

# This implements the addition algorithm as iteration along two sets of ordered 
# digits in a nested fassion, while simultaneously popping a list of reverse
# ordered results, colocating the result and the arguments for storage
bs_carry = list(reversed(carry_digits))
for carry in [False,True]:
    bs_a = bs_carry.copy()
    for a in digits: 
        bs_b = bs_a.copy()
        for b in digits:
            base10_adder[(a,b,carry)] = bs_b.pop() # remove last for next b, and store it
        bs_a.pop() # remove last for the next a
    bs_carry.pop() # remove last for the carry
```
-- leaving not a single mathematical operation to be seen!
Even the iteration is list based as opposed to using numerical indexing.
That fact makes it a shame that the adding function itself uses numerical indexing.

### Removing the last bits of math

Instead of indexing the number strings, it is possible to step over them by place value, while producing the result by appending place values to another list.
The fact that empty lists are boolean false, and that Python lists implement a `.pop()` which yields the last element while removing it from the underlying list vastly simplifies the logic.

```python
def glorious_math_free_add(ns1, ns2):
    ''' Adds two numbers stored as strings, without using intermediate numeric types. '''
    ns1, ns2 = list(ns1), list(ns2)
    result = [] # accumulate the result by place value
    carry = False
    while ns1 or ns2:
        intermediate, carry = base10_adder[(
            ns1.pop() if ns1 else '0',
            ns2.pop() if ns2 else '0',
            carry
        )]
        result.append(intermediate)
    if carry:
        result.append('1')
    return ''.join(list(reversed(result)))
```

All told, that's pretty concise for what it is.

## Performance, or lack thereof

Unfortunately, the profits generated from such an advanced approach will be diluted by the fact that it's at least five times slower than the originally suggested approach:
```python
def nonstupid_add(ns1, ns2):
    return str(int(ns1)+int(ns2))
``` 

Though be fair, the comparison is way closer than I would have expected, and is a testament to performance improvements in Python over the years, as the `int()` method and numeric addition is assuredly running in native code.
To really do it justice, first generate some really big numbers.
```python
import numpy as np
bignum = lambda size: ''.join(np.random.choice(digits, size=size))
bignum_a = bignum(1000)
bignum_b = bignum(1000)
```

```plaintext
%timeit glorious_math_free_add(bignum_a,bignum_b)

>> 97.2 μs ± 197 ns per loop (mean ± std. dev. of 7 runs, 10,000 loops each)

%timeit nonstupid_add(bignum_a,bignum_b)

>> 16.2 μs ± 159 ns per loop (mean ± std. dev. of 7 runs, 100,000 loops each)
```

## Runner up: simply avoiding add, for some reason

You may also hypothesize that the interviewer was simply asking to avoid the numeric add operator.
Perhaps the company purchased some budget hardware that can do everything _except_ add numbers, who could say.
Fortunately, the addition operator is very simple in binary, and computers tend to represent (and allow you to manipulate) integer numbers in their binary representation.

You can, as it turns out, iteratively apply binary `XOR`, `AND`, and `SHIFT` operations to two binary representations to add them.
This works because `a XOR b` is the sum of each bit pair ignoring carry, and `a AND b` is a marker of whether the bit pair sum carried, per bit.
Therefore, switching to math-style syntax --
$$
\begin{align}
a' &= a \oplus b \\\\
b' &= (a \otimes b) < < 1
\end{align}
$$
-- gives two new numbers $a'$ and $b'$ which have the same _sum_ as $a$ and $b$ with the important property that $b'$ is highly likely to have fewer bits set than $b$ due to the `AND` with $a$.
Applying this iteratively gives yet another interesting result --
```python
def no_add_but_still_add(ns1, ns2):
    x, y = int(ns1), int(ns2)
    while y:
        xn = (x ^ y)
        yn = (x & y) << 1
        x = xn
        y = yn
    return str(x)
```
-- which moves the bits from `y` to `x` as carries cascade down.
This is a process that will terminate in a finite number of steps bounded by the number of bits, while preserving the sum of `x` and `y`.
The result is by construction that the sum ends up in `x` when `y` is zero.

Who's to say who was right, though.
