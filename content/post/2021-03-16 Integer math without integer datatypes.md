---
title: Integer math algorithms without integer datatypes or math-specific hardware
date: '2021-03-31'
categories:
  - Math
  - Programming
description: How to implement integer arithmetic as an algorithm without math-specific hardware. 
slug: math-as-an-algorithm
toc: true
---

I previously posted about [simple, programmable, Turing-complete machines](/post/2021/01/21/l2-lisp-machine-python/).
That post discussed a programmable machine that optimized ease-of-programming and ease-of-implementation while still being able to run any program.
With those goals in mind I put together a Python package [L2](https://github.com/BenLand100/L2) which emulates such a simple machine in software.
For the L2 emulator, I used math operations and datatypes that were simply provided by Python to create the mathematical functionality.
This is a bit of a cop out, because mathematical operations are a very important part of computing, and a machine that simply borrows them from Python, which uses the CPUs math operations, cannot really said to be simple.
With that in mind, and in light of a recent post about [implementing `exp` and other functions](/post/2021/02/24/power-without-math-lib/) without using some standard library, I thought it would be neat to try to bootstrap mathematical operations from the [cells](post/2021/01/21/l2-lisp-machine-python/#cells), [symbols](post/2021/01/21/l2-lisp-machine-python/#symbols), and [primitive operations](/post/2021/01/21/l2-lisp-machine-python/#special-primitive-operations) of L2.

This post will focus on integer math, while floating point math will be a topic for a future post.
Because L2 is _very simple_, not as easy to prototype in, and less comprehensible to people not familiar with LISP, I'll be writing Python code that uses only features easily portable to L2.

## Representation

Math, especially integer math, is all about counting, and anything that can be counted can be used to represent numbers.
For instance, a list (made of Cell objects) could represent a positive integer with its length.
To add two lists, one could be concatenated to the other.
To subtract, the tail of the longer list would represent the difference.
Multiplication and division could be bootstrapped with repeated addition and subtraction.
Negative numbers could have a special first element to identify them.

This list representation is not particularly efficient, since the memory used is linear with the size of the integer.
The [Roman solution to this problem](https://en.wikipedia.org/wiki/Roman_numerals) was to introduce several symbols of greater value, which meant that 1 (I), 5 (V), 10 (X), etc., could be represented by one numeral.
This pattern continued up to 1000 (M), with some more complicated rules to compress bigger numbers.
Manipulating Roman numerals can be quite difficult.
Addition and subtraction are manageable with some rules (I plus III is IV, I more than IV is V, and I more than IV is VI), but this is complex.
Multiplication (division) by repeated addition (subtraction) would work, taking into account the same (exhaustive) rules.

The ["modern" solution](https://en.wikipedia.org/wiki/Positional_notation) to notation is to represent some small quantity of numbers (called the base, $b$) uniquely, and then use the position of those number symbols in a list to represent how many powers of the base are represented. 
So the quantity $A$ which has a number symbol in the $i$th position, $A_i$, would be the the count of $b^i$ values in the quantity, usually counted from the right.
$$ A = \\{A_n,A_{n-1},...,A_{1},A_{0}\\} = 1234 $$
$$ A = \sum^n_{i=0} A_i b^i = 4\times10^0 + 3\times10^1 + 2\times10^2 + 1\times10^3 $$
This allows a number to be represented in approximately $\log_{10} N$ characters - much better than linear!
The mathematical operations you learned in elementary school that operate on each position at a time can also be applied to these numbers, as you well know.

To perform those algorithms, one must only know the result for each pair of digits (for operations with two arguments, like addition, etc).
This means an operation has roughly $b^2 = 10^2 = 100$ rules that need to be defined.
A simple language like L2 would have no problem enumerating these rules, or even keeping track of ten possible symbols in lists.
But there are simpler representations than $b=10$.
First, note that $b=1$ is essentially the same as the list-length encoding above: each position adds a factor of $1$ to the quantity. 
The case of $b=2$, known as binary notation, has the same logarithmic growth as all values larger than $b=1$, but keeps the number of possible symbols to a minimum.
The smallness of the number of symbols means that the rules for implementing operations are correspondingly fewer.
This, in addition to the fact that the two symbols can correspond to "on" and "off" makes binary the most popular way to represent numbers in ordinary computers.
Such systems still require a mechanism for converting human-readable base-10 (and often base-8 or base-16) such that the math algorithms implemented in base-2 are useful.

### Pre-bootstrapping

I'll start with a Python function that converts Python integers into a representations that would work for L2: a list of symbols in position notation.
This list will correspond to the $A_i$ values in the summation above, where the base is understood from the number of possible symbols.
The value of the symbols will be represented by their position in the list.
To be extra clear that no numbers are being used in this representation of numbers, I'll use `'i'` to correspond to one and `'o'` to correspond to zero. 
```python
bin_rep = ['o','i']

def rep_int(i,rep=bin_rep):
    '''Turn a python integer into a base rep integer representation'''
    if not i:
        return []
    else:
        res = [] if i > 0 else ['-'] 
        if i < 0:
            i = -i
        while i > 0:
            res.append(rep[i%len(rep)])
            i = i // len(rep)
        return res
```
This method takes a Python integer and performs Python integer division `//` and remainder `%` operations to arrive at the representation.
The algorithm here is to calculate the lowest place value as the remainder of integer division by the base.
The result of the division then becomes the value used to calculate the next lowest place value.
$$ A_i = N_{i-1}\mod b $$
$$ N_i = \lfloor N_{i-1} / b \rfloor $$
where $N_{-1} = A$, the number to be encoded in this base.
These mathematical operations will be re-implemented later; for now, this is just to generate some representations to work with.
```python
rep_int(128)
```
```
['o', 'o', 'o', 'o', 'o', 'o', 'o', 'i']
```
Note that only the 7th index ($2^7 = 128$) has the one symbol.
This method can also convert a Python integer to any base.
```python
rep_int(128,rep=['o','i','j'])
```
```
['j', 'o', 'j', 'i', 'i']
```
Where a two symbol in the ones place, zero symbol in threes place, twp symbol in nines place, and one symbols in the twenty-sevens and eighty-ones place.
If you're following, that's base three for $2\times1+0\times3+2\times9+1\times27+1\times81=128$.
And since base-10 is included in "any base":
```python
rep_int(128,rep='0123456789')
```
```
['8', '2', '1']
```
Which clearly drives the point home that this representation has the least significant place first: annoying perhaps for a modern person, but convenient for calculation purposes.

I'll make an array of small numbers in binary encoding for testing purposes as the algorithms for mathematical operations are developed.
```python
numbers = [rep_int(i) for i in range(10)]
```
```
[[],
 ['i'],
 ['o', 'i'],
 ['i', 'i'],
 ['o', 'o', 'i'],
 ['i', 'o', 'i'],
 ['o', 'i', 'i'],
 ['i', 'i', 'i'],
 ['o', 'o', 'o', 'i'],
 ['i', 'o', 'o', 'i']]
```

Which clearly drives the point home that this representation has the least significant place first: annoying perhaps for a modern person, but convenient for calculation purposes.

Even though these numbers are least significant bit first, I'll choose to represent negative numbers as a signed magnitude by appending a special minus symbol `'-'` to them.
```python
rep_int(-128,rep='0123456789')
```
```
['-', '8', '2', '1']
```

With this representation, any negative or positive integer can be stored with an arbitrary number of bits as a list of said bits, with zero is represented as an empty list.

## Manipulation
With a representation of integers as lists of symbols, what's left is to define algorithms that manipulate the representations like mathematical operators.
This will be done in python, but using a subset of the language that is equivalent to L2 code.
The datatypes provided by the L2 machine are unique [`Symbols`s](post/2021/01/21/l2-lisp-machine-python/#symbols) and that contain two values, either another `Cell` or a `Symbol`.
`Cell`s are used to form linked lists, which I'll use Python `list`s to replicate. 
L2's primitive `Cell` functions are implemented as follows:
```python
def getl(list):
    return list[0]

def getr(list):
    return list[1:] if list else None

def cell(item,list):
    return [item] + list # 1 of 2 plus signs in this code
    
def append(item,list): # not a primative
    return list + [item] # 2 of 2 plus signs in this code
    
def reverse(list): # not a primative
    if not list:
        return []
    return append(getl(list),reverse(getr(list)))
```
Just like L2, an empty list tests as `False` and a list with elements tests as `True`.

Methods can be constructed to test for negativity and negate an integer representation.
```python
def is_negative(rep):
    return rep and getl(rep) == '-'

def negate(rep):
    if not rep:
        return rep
    elif is_negative(rep):
        return getr(rep) #getr pop's the negative symbol
    else:
        return ['-']+rep
```

To clean up any representations with leading zero symbols, or any other symbols, they can be removed from the right side.
```python
def rep_strip(res,remove='o'):
    if not res:
        return []
    keep = rep_strip(getr(res))
    if keep or getl(res) != remove:
        return cell(getl(res),keep)
    else:
        return []
```

### Addition and Subtraction

The addition algorithms, like the corresponding algorithm to add base-10 numbers, will add numbers in columns of place value, carrying to the next place value if there is overflow.
Summing two bits, $A$ and $B$, there can be a maximum result $R$ and carry $C$ of one.

| $A$ | $B$ |   | $R$ | $C$ |
|---|---|---|---|---|
| 0 | 0 | $\rightarrow$ | 0 | 0 |
| 0 | 1 | $\rightarrow$ | 1 | 0 |
| 1 | 0 | $\rightarrow$ | 1 | 0 |
| 1 | 1 | $\rightarrow$ | 0 | 1 |

This is easy to implement in code with cascading `if` statements:
```python
def add_bin_bit_nocarry(a,b):
    if a == 'o':
        if a == b:
            return 'o','o'
        else:
            return 'i','o'
    else:
        if a == b:
            return 'o','i'
        else:
            return 'i','o'
```

In practice, adding the bits at a place value also requires including the carry from a less significant place value.
This means adding three bits, $A$, $B$, and $C'$ is necessary.
This can be accomplished by chaining three copies of the two-bit adder.
Since the result of adding three bits is at most three, a result and carry bit is still all that is required as the result.
```python     
def add_bin_bit(a,b,carry):
    res,carry_a = add_bin_bit_nocarry(a,b) # add the bits
    res,carry_b = add_bin_bit_nocarry(res,carry) # add carry to the result
    carry,_ = add_bin_bit_nocarry(carry_a,carry_b) # only one operation could carry, so no carry here
    return res,carry
```

Then some recursion can be used to iterate over and add the bits in two representations, with some logic to handle numbers with different bit lengths.
The carry is passed to each place value, and initialized to zero for the ones place.
```python
def add_bin_rep(a,b,carry='o'):
    if a and b:
        res,carry = add_bin_bit(getl(a),getl(b),carry)
        return cell(res,add_bin_rep(getr(a),getr(b),carry))
    elif a: # a was longer
        res,carry = add_bin_bit_nocarry(getl(a),carry)
        return cell(res,add_bin_rep(getr(a),[],carry))
    elif b: # b was longer
        res,carry = add_bin_bit_nocarry(getl(b),carry)
        return cell(res,add_bin_rep([],getr(b),carry))
    elif carry != 'o': # sum resulted in more bits than a or b
        return cell(carry,[])
    else:
        return []
```

So far this only handles unsigned numbers. 
Because I've chosen to use signed magnitude with arbitrary bit depth instead of something like [two's complement](https://en.wikipedia.org/wiki/Two%27s_complement), additional logic will be necessary to handle adding numbers with different signs.
```python
def add_bin_rep_signed(a,b):
    if is_negative(a) and is_negative(b): #same sign
        return negate(add_bin_rep(getr(a),getr(b)))
    elif not is_negative(a) and not is_negative(b): #same sign
        return add_bin_rep(a,b)
    elif is_negative(a): #opposite sign
        a = getr(a)
        return sub_bin_rep(b,a)
    elif is_negative(b): #opposite sign
        b = getr(b)
        return sub_bin_rep(a,b)
```

However, note here that I've used a yet undefined function `sub_bin_rep` to subtract absolute values numbers when the signs are different.
Subtraction is fortunately very similar to addition, just with different single bit rules, and borrowing $B$ from higher place values instead of carrying.
| $A$ | $B$ |   | $R$ | $B$ |
|---|---|---|---|---|
| 0 | 0 | $\rightarrow$ | 0 | 0 |
| 0 | 1 | $\rightarrow$ | 1 | 1 |
| 1 | 0 | $\rightarrow$ | 1 | 0 |
| 1 | 1 | $\rightarrow$ | 0 | 0 |
```python
def sub_bin_bit_noborrow(a,b):
    if a == 'o':
        if a == b:
            return 'o','o'
        else:
            return 'i','i'
    else:
        if a == b:
            return 'o','o'
        else:
            return 'i','o'
        
def sub_bin_bit(a,b,borrow):
    res,borrow_a = sub_bin_bit_noborrow(a,b)
    res,borrow_b = sub_bin_bit_noborrow(res,borrow)
    borrow,_ = add_bin_bit_nocarry(borrow_a,borrow_b)
    return res,borrow
```

Unlike addition of positive numbers, which always results in positive numbers, subtraction can result in a negative number.
The [ring nature](https://en.wikipedia.org/wiki/Commutative_ring) of two's complement makes this a non-issue for hardware implementations with fixed-length representations, since the borrows from higher place value bits eventually truncate.
For example subtracting one from an 8-bit zero looks like this in twos complement:
$$ 
\begin{array}{r}
 & 0 0 0 0 0 0 0 0 \\\\
-& 0 0 0 0 0 0 0 1 \\\\
\hline
 & 1 1 1 1 1 1 1 1
\end{array}
$$
The series of one bits technically continues to the left in an infinite series as a [2-adic number](https://en.wikipedia.org/wiki/P-adic_number), but because an 8-bit number is fixed to
eight bits, only a finite number of bits is kept, and a borrow flag might be set to indicate the sign changed.
Note that with all bits set, the value of this collection of bits as an unsigned number is $255$.
Since the signed value of a twos complement number $n$ of length $d$ with the highest bit set is given by $n - 2^d = 255 - 2^8 = -1$, this truncation eight bits works fine.
Without a fixed number of bits (infinite bits), this breaks down, though in some conceptual sense, the number that borrowed one from infinity would be one less than infinity.

To get around infinite lengths, I implement an intermediate subtraction function `sub_bin_rep_` which will return a truncated 2-adic number with one more bit than either argument if the result is negative.
```python
def sub_bin_rep_(a,b,borrow='o'):
    if a and b:
        res,borrow = sub_bin_bit(getl(a),getl(b),borrow)
        return cell(res,sub_bin_rep_(getr(a),getr(b),borrow))
    elif a:
        res,borrow = sub_bin_bit_noborrow(getl(a),borrow)
        return cell(res,sub_bin_rep_(getr(a),[],borrow))
    elif b:
        res,borrow = sub_bin_bit('o',getl(b),borrow)
        return cell(res,sub_bin_rep_([],getr(b),borrow))
    elif borrow != 'o':
        return cell(borrow,[]) # this borrow would repeat forever
    else:
        return []
```
This result can be tested to see if it has more bits than the arguments, and if so, use the two's complement formula above to find the magnitude of the 2-adic number.
```python
def sign_correct(a,b,res):
    '''Subtraction can return a truncated 2-adic or twos-complement number, 
       convert to a negative magnitude if this happens.'''
    res = rep_strip(res)
    def longer(a,b,res):
        if res and ((not a) and (not b)):
            return True
        elif not res:
            return False
        else:
            return longer(getr(a) if a else [], getr(b) if b else [], getr(res))
    if longer(a,b,res):
        # twos is the value 2**d where d is the number of bits in res
        twos =  append('i',['o' for b in res]) # L2 can map functions
        return negate(rep_strip(sub_bin_rep_(twos,res)))
    else:
        return res
```
The true subtraction function `sub_bin_rep` can then be implemented as:
```python 
def sub_bin_rep(a,b,borrow='o'):
    return sign_correct(a,b,sub_bin_rep_(a,b,borrow=borrow))
```

So far these functions have only dealt with positive magnitudes as inputs, and only subtraction can return a negative magnitude. 
To write functions that handle signed numbers, each operation should check the sign of the inputs, and perform the correct operation.
An advantage of the fixed-length representations using twos complement ring is that this distinction is unnecessary (addition is just addition, regardless of sign), but I wanted arbitrary-length numbers here, so the extra logic is required
```python
def add_bin_rep_signed(a,b):
    if is_negative(a) and is_negative(b): #same sign
        return negate(add_bin_rep(getr(a),getr(b)))
    elif not is_negative(a) and not is_negative(b): #same sign
        return add_bin_rep(a,b)
    elif is_negative(a): #opposite sign
        return sub_bin_rep(b,getr(a))
    elif is_negative(b): #opposite sign
        return sub_bin_rep(a,getr(b))
    
def sub_bin_rep_signed(a,b):
    if is_negative(a) and is_negative(b): #same sign
        return negate(sub_bin_rep(getr(a),getr(b)))
    elif not is_negative(a) and not is_negative(b): #same sign
        return sub_bin_rep(a,b)
    elif is_negative(a): #opposite sign
        return negate(add_bin_rep(getr(a),b))
    elif is_negative(b): #opposite sign
        return add_bin_rep(a,getr(b))
```

Using the `numbers` generated earlier, these functions can be tested right away.
```python
print('two',add_bin_rep_signed(numbers[1],numbers[1]))
print('negative two',add_bin_rep_signed(numbers[4],negate(numbers[6])))
print('two',sub_bin_rep_signed(numbers[3],numbers[1]))
print('negative one',sub_bin_rep(numbers[1],numbers[2]))
```
```
two ['o', 'i']
negative two ['-', 'o', 'i']
two ['o', 'i']
negative one ['-', 'i']
```

### Multiplication

Multiplication of position notation numbers is also fairly straightforward, and does not have to resort to repeated addition, which would scale linearly with the magnitude of one of the numbers.
Instead, one argument $B = \\{B_0,...,B_n\\}$ is broken up by place value, and each place value is separately multiplies the other argument $A = \\{A_0,...,A_m\\}$. 
These intermediate values are shifted left and zero padded such that the ones place lines up with the position of the place value used in multiplication, and then added.
With this done in base $b$, and a place value position $i$, this shifting is the same as a multiplication by a power of $b^i$.
This can be seen by expanding $A$ and $B$ into their base $b$ representations.
$$ AB = \sum_{i=0}^n A B_i b^i = \sum_{i=0}^n \sum_{j=0}^m (A_j b^j) B_i b^i $$

In binary this operation is _even easier_ because there are only two possible values to multiply by: one, which is the identity, and zero, which is zero. 
So, depending on whether the bit in one argument is one or zero, the other argument is either added or not, and the result is shifted to the correct position.
This can easily be done with recursion, and a little logic to handle signs.
```python
def mul_bin_rep(a,b):
    if not a or not b:
        return []
    if getl(b) == 'i':
        low = a
    else:
        low = []
    high = cell('o',mul_bin_rep(a,getr(b)))
    return add_bin_rep(low,high)

def mul_bin_rep_signed(a,b):
    if is_negative(a) and is_negative(b): #same sign
        return mul_bin_rep(getr(a),getr(b))
    elif not is_negative(a) and not is_negative(b): #same sign
        return mul_bin_rep(a,b)
    elif is_negative(a): #opposite sign
        return negate(mul_bin_rep(b,getr(a)))
    elif is_negative(b): #opposite sign
        return negate(mul_bin_rep(a,getr(b)))
```

Testing with the numbers generated earlier demonstrates that this works.
```python
print('six',mul_bin_rep_signed(numbers[3],numbers[2]))
print('negative eighty-one',mul_bin_rep_signed(numbers[9],numbers[9]))
print('negative eighty-one',mul_bin_rep_signed(numbers[9],negate(numbers[9])))
```
```
six ['o', 'i', 'i']
negative eighty-one ['i', 'o', 'o', 'o', 'i', 'o', 'i']
negative eighty-one ['-', 'i', 'o', 'o', 'o', 'i', 'o', 'i']
```

### Division

As with everything before, division algorithms are very similar to the [long division](https://en.wikipedia.org/wiki/Long_division) technique taught in elementary school, with the exception that instead of computing a fractional part if the divisor is not an integer factor of the dividend, the integer remainder will be returned along with the integer result.
This is a more efficient position notation algorithm than repeated subtraction, but is more complicated than the multiplication algorithm. 
1. The divisor is subtracted from the highest place value in the dividend as many times as possible without going negative.
2. If the number of times the divisor can be subtracted without going negative gives the highest place value of the result.
3. The remaining value after subtraction is multiplied by the base and added to the next place value of the dividend.
4. The subtraction without going negative is performed again, giving the next-highest place value.
5. Repeat at step 3 until there are no more place values in the dividend.
6. The result has been calculated, along with some possibly nonzero remainder

This algorithm simplifies a bit in binary because the subtraction step will require either zero or one subtraction, so an attempted subtraction is either negative or not.
Again, recursion can be used to implement this algorithm to iterate over place values.
```python
def div_bin_rep(a,b):
    if not a:
        return [],[]
    div,rem = div_bin_rep(getr(a),b)
    rem = cell(getl(a),rem)
    cmp = sub_bin_rep_signed(rem,b)
    if is_negative(cmp):
        if div: #suppress zeros in high bits
            div = cell('o',div)
        rem = rep_strip(rem)
    else:
        div = cell('i',div)
        rem = cmp
    return div,rem

def div_bin_rep_signed(a,b):
    if is_negative(a) and is_negative(b): #same sign
        return div_bin_rep(getr(a),getr(b))
    elif not is_negative(a) and not is_negative(b): #same sign
        return div_bin_rep(a,b)
    elif getl(a) == '-': #opposite sign
        return [negate(x) for x in div_bin_rep(b,getr(a))]
    elif getl(b) == '-': #opposite sign
        return [negate(x) for x in div_bin_rep(a,getr(b))]
```

And you can see that the division result and remainder are calculated correctly.
```python
print('one, remainder zero',div_bin_rep(numbers[1],numbers[1]))
print('two, remainder one',div_bin_rep(numbers[5],numbers[2]))
```
```
one, remainder zero (['i'], [])
two, remainder one (['o', 'i'], ['i'])
```

## Converting Representations

With addition, subtraction, multiplication, and division, all the integer math one needs can be bootstrapped.
To demonstrate this, I'll implement some functions to convert representations in one base to another base, which will let L2 handle converting to and from human-readable base-10 numbers.
But first, some utilities for representing list lengths, element positions, and list indexing.
```python
zero = []
one = ['i']

def length(list):
    if not list:
        return zero
    return add_bin_rep(one,length(getr(list)))

def position(list,x):
    if getl(list) == x:
        return zero
    return add_bin_rep(one,position(getr(list),x))

def take(list,i):
    if not list:
        return None
    elif not i:
        return getl(list)
    else:
        return take(getr(list),sub_bin_rep(i,one))
```
`length` will return the total length of a list in a binary representation.
```python
length(['0','1','2','3'])
```
```
['o', 'o', 'i']
```
`position` will return a binary representation of the index of an item in a list.
```python
position(['0','1','2','3'],'2')
```
```
['o', 'i']
```
While `take` will return the item in a list at binary representation of the index.
```python
arr = ['0','1','2','3']
take(arr,position(arr,'2'))
```
```
'2'
```

With these parts, a `from_rep` function can be implemented to convert any base into a binary representation, using the same algorithm in the earlier test method `rep_int`.
A `from_str` method wraps this to convert a more standard most-to-least-significant ordering of digits into binary representations. 
```python
def from_rep_(i,rep,base):
    if not i:
        return []
    res = position(rep,getl(i))
    higher = from_rep_(getr(i),rep,base)
    return add_bin_rep(res,mul_bin_rep(base,higher))

def from_rep(i,rep=['0','1','2','3','4','5','6','7','8','9']):
    if not i:
        return []
    else:
        base = length(rep)
        if is_negative(i):
            return negate(from_rep_(i,rep,base))
        else:
            return from_rep_(i,rep,base)
        
def from_str(digits,rep=['0','1','2','3','4','5','6','7','8','9']):
    if is_negative(digits):
        return from_rep(negate(reverse(negate(digits))),rep=rep)
    else:
        return from_rep(reverse(digits),rep=rep)
```

Now, a string in any base (which is really just a list of digit symbols) can be converted to the binary number representations the mathematical algorithms can work with. 
```python
from_str('37')
```
```
['i', 'o', 'i', 'o', 'o', 'i']
```

Finally, to convert any base representation to any other base representation, a function `to_rep` and matching `to_str` can be written.
```python
def to_rep_(i,rep,base):
    if not i:
        return []
    i,rem = div_bin_rep(i,base)
    higher = to_rep_(i,rep,base)
    return cell(take(rep,rem),higher)

def to_rep(i,rep=['0','1','2','3','4','5','6','7','8','9']):
    if not i:
        return []
    else:
        base = length(rep)
        if is_negative(i):
            i = negate(i)
            return negate(to_rep_(i,rep,base))
        else:
            return to_rep_(i,rep,base)

def to_str(i,rep=['0','1','2','3','4','5','6','7','8','9']):
    i_rep = to_rep(i,rep=rep)
    if is_negative(i_rep):
        return ''.join(negate(reverse(negate(i_rep))))
    else:
        return ''.join(reverse(i_rep))
```

This can be tested end-to-end to ensure the input is the same as the output.
```python
i = from_str('37')
print(i)
s = to_str(i)
print(s)
```
```
['i', 'o', 'i', 'o', 'o', 'i']
37
```

## Factorial

After putting all this effort into implementing arbitrary length integer representations and the algorithms to manipulate them, one can try out something that is difficult to do even with the 64-bit integer representations available on modern computers: compute large factorials. 
The factorial of $A$ is written as $A!$ and is the product of all positive integers less than or equal to A.
$$ A! = \prod_{i=1}^A i $$
Factorials get large fast, and indeed is one of the fastest-growing classes of functions. 
Something like the factorial of 100 is so large that it will overflow a 64-bit integer, approximately $9.3\times10^{157}$, but should be calculable with the arbitrary-length integer representations developed here.

Code to compute factorials is easy to write with recursion.
```python
def factorial(i):
    if not i:
        return one
    return mul_bin_rep(i,factorial(sub_bin_rep(i,one)))
```

And with the ability to convert to and from base-10 representations, the result of $100!$ is easy to obtain:
```python
to_str(factorial(from_str('100')))
```
```
'93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000'
```
Which, [according to WolframAlpha](https://www.wolframalpha.com/input/?i=100!) is correct.

## Next Steps

Ultimately I want to convert all this Python code into L2 code, and have made some progress on that front...
```lisp
 (defun is-negative (int) (if int (eq (getl int) '-)))
 (defun negate (int) (if int (if (eq (getl int) '-) (getr int) (cell '- int))))
 (defun bit-strip (int) (if int (let ((keep (bit-strip (getr int)))) 
     (if (or keep (not (eq (getl int) 'o))) (cell (getl int) keep) ) )))
     
 (defun add-bin-bit-nocarry (a b) (if (eq a 'o)
     (if (eq a b) (cell 'o 'o) (cell 'i 'o) )
     (if (eq a b) (cell 'o 'i) (cell 'i 'o) ) ))
     
 (defun add-bin-bit (a b carry) (let ((sum_a (add-bin-bit-nocarry a b) )) 
     (let ((sum_b (add-bin-bit-nocarry (getl sum_a) carry) ))
         (let ((carry_sum (add-bin-bit-nocarry (getr sum_a) (getr sum_b)) )) 
             (cell (getl sum_b) (getl carry_sum)) ) ) ))
 
 (defun sub-bin-bit-noborrow (a b) (if (eq a 'o)
     (if (eq a b) (cell 'o 'o) (cell 'i 'i) )
     (if (eq a b) (cell 'o 'o) (cell 'i 'o) ) ))
     
 (defun sub-bin-bit (a b borrow) (let ((diff_a (sub-bin-bit-noborrow a b) )) 
     (let ((diff_b (sub-bin-bit-noborrow (getl diff_a) borrow) ))
         (let ((borrow_sum (add-bin-bit-nocarry (getr diff_a) (getr diff_b)) )) 
             (cell (getl diff_b) (getl borrow_sum)) ) ) ))
             
 (defun add-bin-unsigned (a b &optional carry) (let ((carry (if carry carry 'o))) (cond 
     ((and a b) (let ((s (add-bin-bit (getl a) (getl b) carry))) 
         (cell (getl s) (add-bin-unsigned (getr a) (getr b) (getr s))) ) )
     (a nil) ;WIP
     (b nil) ;WIP
     ((not (eq carry 'o)) `(,carry))
     ('t '())
 )))
```
...but have become distracted by a desire to implement either [floating point numbers](https://en.wikipedia.org/wiki/Floating-point_arithmetic) or some other fractional representation in my mock-up Python code, in order to do [real](https://en.wikipedia.org/wiki/Real_number) math (pun intended).
Because I'm not tied to a particular hardware architecture, [IEEE 754 encoding](https://en.wikipedia.org/wiki/IEEE_754) is not very attractive to re-implement. 
That said, an exponential representation with a maximum precision does have some attractive features, especially since most fractions have non-terminating representations in different bases.
Thinking about the choice of representation for fractional numbers in L2 does give some insight into why LISP dialects have a ratio datatype to exactly store any [rational](https://en.wikipedia.org/wiki/Rational_number) number, which could also arbitrarily approximate any real but not rational number.
Perhaps ratios in a future post, and floating points later.


