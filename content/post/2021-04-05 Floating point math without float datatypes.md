---
title: Floating point math algorithms without float datatypes or math-specific hardware
date: '2021-04-05'
categories:
  - Math
  - Programming
description: How to implement floating point arithmetic as an algorithm without math-specific hardware. 
slug: real-math-as-an-algorithm
toc: true
---

Following the [previous post on implementing integer math](/post/2021/03/31/math-as-an-algorithm/) without utilizing some lower-level math implementation, this post will extend the functionality to approximate [real numbers](https://en.wikipedia.org/wiki/Real_number) using the building blocks for representing integers.
As before, this is targeted for the simple LISP-like language [L2](/post/2021/01/21/l2-lisp-machine-python/) but will be done with Python code first, using only functionality present in L2.

## Representation

[Rational numbers](https://en.wikipedia.org/wiki/Rational_number) can always be represented exactly as ratios of integers, or a [fraction](https://en.wikipedia.org/wiki/Fraction).
Many rational number can be represented exactly as a [decimal fraction](https://en.wikipedia.org/wiki/Decimal#Decimal_fractions) that terminates (has a finite number of digits), and the remaining rational numbers can be represented as decimal fractions with repeating patterns at the end.
To work with only rational numbers, a representation that stores the numerator and denominator can exactly represent any possible calculation.

$$ \frac{1}{3} = 0.33333333\overline{3} $$

Real numbers that are not rational numbers, that is [irrational numbers](https://en.wikipedia.org/wiki/Irrational_number) like $\pi$, $e$ or $\sqrt{2}$, also do not terminate, but do not have any repeating pattern in their decimal fraction representation.
Such numbers cannot be represented exactly in [positional notation](https://en.wikipedia.org/wiki/Positional_notation) but can be represented to any desired precision by computing a sufficient number of digits.
An argument can be made that any finite number of digits is necessarily a rational number, and can thus be represented by a fraction.
This means rational numbers can be used to approximate any real number to arbitrary precision.

$$ \pi \approx 3.14159 = \frac{314159}{100000} $$

Taking this a step further, this can be written in exponential notation.

$$ \frac{314159}{100000} = 314159 \times 10^{-5} $$

Where, in base-10, the exponent tracks how many place values from the end of the multiplying number the "ones place" should be, and the total number of digits directly gives the precision.
From an algorithmic manipulation perspective, this is a bit more convenient to work with than a ratio of two arbitrary integers, since it requires the denominator to be a power of the base, and changing the exponent is the same as adding or removing digits from the numerator.
This is the concept of [floating point representation](https://en.wikipedia.org/wiki/Floating-point_arithmetic) that is ubiquitous in computing for approximating real numbers.
In fact

### From positional notation

Since the integer representation developed in the [previous post](/post/2021/03/31/real-math-as-an-algorithm/) manipulates base-2 (binary) numbers, the floating point representation will use powers of 2 for the exponent.
This preserves the behavior that truncating a digit of the [significand](https://en.wikipedia.org/wiki/Significand) only requires increasing the exponent by one to represent the same number with less accuracy.
So, the real number N will be approximated by the rational number $N'$ represented by an integer significand, $a$, and an exponent of two, $b$.
$$ N \approx N' =  a \times 2^b $$
This is analogous to [IEEE 754](https://en.wikipedia.org/wiki/IEEE_754) encoding, except that here the significand is an integer and IEEE 754 represents the significand as a fractional value. 

The next step is converting positional notation to this form.
To obtain the binary fraction digits that correspond to a decimal fraction's digits, treat the integer and fractional parts separately
Split the decimal fraction into two parts, the part before the decimal point (integer part $i$) and part after the decimal point (fractional part $f$).
The integer part of a decimal fraction can be easily converted into binary digits with the `rep_to_bin_rep` function developed in the last post.
These digits go before the decimal point in the binary fraction.
To calculate the binary fraction digits after the decimal point treat the fractional part as a true fraction represented by an integer given by the digits in the fractional part divided by the correct power of 10. 
In other words, if the decimal fraction represents the rational number $N$, then
$$ N = i + \frac{f}{10^p} $$
where we have already dealt with the integer part $i$ and are trying to compute $f/10^p$, which is less than one. 
An algorithm to compute the fractional digits in base two follows.
1. Multiply $f$ by two to get a new $f$.
2. If the new $f$ is greater than $10^p$, the next binary digit is one, and subtract $10^p$ from $f$.
3. Otherwise, the next binary digit is zero, and $f$ remains unchanged.
4. Repeat at step 1 with the current $f$ until $f$ is zero or the desired number of digits is obtained.

An implementation of this algorithm using recursion is not too tricky.
```python
def bin_rep_to_bin_frac(rem,dividend,max_bits,counting): 
    if not max_bits:
        return []
    rem = cell('o',rem)
    cmp = sub_bin_rep_signed(rem,dividend)
    if is_neg_bin_rep(cmp):
        bit = 'o'
    else:
        bit = 'i'
        rem = cmp
        counting=True
    if rem:
        if counting:
            max_bits = sub_bin_rep(max_bits,b_one)
        return append(bit,bin_rep_to_bin_frac(rem,dividend,max_bits,counting))
    else:
        return [bit]
```

This process only terminates when the decimal fraction can be represented exactly in binary, which is not the case for most decimal fractions. 
The reason for this is analogous to the reason many fractions have non-terminating, but repeating, decimal fraction representations.
It is therefore a requirement to decide on a maximum number of binary and decimal digits that are roughly equivalent in range.
```python
bin_precision = str_to_bin_rep('70')
dec_precision = str_to_bin_rep('20')
```

Once the binary fraction digits are known for both the integer and fractional parts (to desired position) simply splice them together in place value order to get the binary significand.
The exponent is the negative of the number of bits in the fractional part.
Optionally, but highly suggested, is to trim off any small place value zero bits, or high place value zero bits (if the integer part was zero), and adjust the exponent accordingly.
These operations on digit lists will require some L2 helper functions
```python
def before(a,idx):
    if not a:
        return []
    if not idx:
        return []
    return cell(getl(a),before(getr(a),sub_bin_rep(idx,b_one)))

def after(a,idx):
    if not a:
        return []
    if not idx:
        return getr(a)
    return after(getr(a),sub_bin_rep(idx,b_one))
```

The following method implements the conversion of a standard decimal fraction into a binary fraction representation using the algorithm described above, with logic to ensure at most `max_bits` bits are used to represent the real approximation significant. 
The integer exponent has no constraint.
This float representation will consist of two signed integers in a tuple `(significand,exponent)`.
Note that since the integer representation can already convert any base into binary, this can in turn convert any base fraction into a binary fraction.
```python
def str_to_float_rep(digits,rep=['0','1','2','3','4','5','6','7','8','9'],point='.',max_bits=bin_precision):
    digits = list(digits)
    negative = is_neg_bin_rep(digits)
    if negative:
        digits = getr(digits)
    len = length(digits)
    idx = position(digits,point)
    int_part = reverse(before(digits,idx))
    int_part = rep_strip(int_part,remove=getl(rep))
    frac_part = reverse(after(digits,idx))
    cmp_val = append(element(rep,b_one),[getl(rep) for x in frac_part])
    frac_part = rep_strip(frac_part,remove=getl(rep))
    int_part = rep_to_bin_rep(int_part,rep=rep)
    frac_part = rep_to_bin_rep(frac_part,rep=rep)
    cmp_val = rep_to_bin_rep(cmp_val,rep=rep)
    if int_part:
        counting = True
        max_bits = sub_bin_rep(max_bits,length(int_part))
    else:
        counting = False
    if frac_part:
        frac_part = bin_rep_to_bin_frac(frac_part,cmp_val,max_bits,counting)
    if not length(int_part):
        pre_len = length(frac_part)
        frac_part = rep_strip(frac_part)
        exp = sub_bin_rep(length(frac_part),pre_len)
    else:
        exp = length(int_part)
    bin_frac = frac_part+int_part
    bin_frac = reverse(rep_strip(reverse(bin_frac)))
    exp = sub_bin_rep_signed(exp,length(bin_frac)) 
    if negative:
        bin_frac = neg_bin_rep(bin_frac)
    return bin_frac,exp
```

To test this out and get a feel for the representation:
```python
a = str_to_float_rep('1.24')
print('significand',a[0])
print('exponent',a[1])
print(bin_rep_to_str(a[0]),'* 2^(',bin_rep_to_str(a[1]),')')
print(int(bin_rep_to_str(a[0]))*2.**int(bin_rep_to_str(a[1])))
```
```plaintext
significand ['i', 'o', 'i', 'i', 'i', 'i', 'o', 'o', 'o', 'i', 'o', 'i', 'o', 'o', 'o', 'o', 'i', 'i', 'i', 'o', 'i', 'o', 'i', 'i', 'i', 'i', 'o', 'o', 'o', 'i', 'o', 'i', 'o', 'o', 'o', 'o', 'i', 'i', 'i', 'o', 'i', 'o', 'i', 'i', 'i', 'i', 'o', 'o', 'o', 'i', 'o', 'i', 'o', 'o', 'o', 'o', 'i', 'i', 'i', 'o', 'i', 'o', 'i', 'i', 'i', 'i', 'o', 'o', 'i']
exponent ['-', 'o', 'o', 'i', 'o', 'o', 'o', 'i']
365983402422397504061 * 2^( -68 )
1.24
```

Examining this closer, this says that
$$ 1.24_{10} = 1.\overline{01111000101000011101}_2 $$
where the repeating part of the binary fraction is explicitly repeated until the bit limit is reached.
This is represented as follows.
$$ 1.24 = 365983402422397504061 \times 2^{-68} $$

### To positional notation

Now that fractional notation in any base can be converted into this float representation, it would be good to convert back to decimal fractions to be more human readable.
This uses essentially the same algorithm as converting decimal fractions to binary fractions.
Using the form $a \times 2^b$, note that the number is an integer if $b$ is positive, and only has a fractional part if $b$ is negative.
If there is a fractional part, the number $q + \frac{r}{2^{|b|}}$ can be found by calculating the quotient $q$ and remainder $r$ of the division $a/2^{|b|}$.
Here, $q$ is the integer part, and the fractional part is $\frac{r}{2^{|b|}}$.
Therefore, an algorithm is needed to extract the decimal (or any base) fraction digits of a ratio that is less than one.
This can be done with a generalization of the algorithm used to turn decimal fractions into binary fractions.
1. Multiply the remainder $r$ by the number of digits in the base to get a new $r$.
2. If the new $r$ is less than the divisor $2^{|b|}$, the next digit is zero.
3. Otherwise, the next binary digit is the digit in the base that corresponds to quotient of the division $r/2^{|b|}$, and remainder becomes the new $r$.
4. Repeat at step 1 with this new $r$ until $r$ is zero or the desired number of digits is obtained.

The divisor and dividend can be very big here, making the division operation quite slow, but the divisor is a simple power of two, so repeated subtraction is quite fast.
The dividend is only a bit larger than the divisor, so few subtractions are required for each digit.
This algorithm is implemented as follows.
```python
def bin_rep_to_rep_frac_(rem,dividend,max_digits,counting,rep=['0','1','2','3','4','5','6','7','8','9']):
    if is_neg_bin_rep(max_digits):
        return []
    rem = mul_bin_rep(rem,length(rep))
    #i,rem = div_bin_rep(rem,dividend)
    #this is a more efficient division algorithm when rem ~ b but both are large
    i = b_zero
    while True: 
        cmp = sub_bin_rep(rem,dividend)
        if is_neg_bin_rep(cmp):
            break
        else:
            i = add_bin_rep(i,b_one)
            rem = cmp
            counting = True
    digit = element(rep,i)
    if rem:
        if counting:
            max_digits = sub_bin_rep(max_digits,b_one)
        return append(digit,bin_rep_to_rep_frac_(rem,dividend,max_digits,counting,rep=rep))
    else:
        return [digit]
```

Note that this algorithm produces one additional digit than requested when more digits are required for an exact representation.
This is done so that the final result can be rounded.
Rounding is not entirely trivial, but this implementation will, if rounding is necessary, convert the desired digits back into binary, add one, and convert back into decimal.
The logic to maintain the correct number of leading zeros, which signify the place value, has to take into account possible carry into a zero digit, and re-append the correct number of leading zeros to the rounded result.
```python
def bin_rep_to_rep_frac(rem,dividend,max_digits,counting,rep=['0','1','2','3','4','5','6','7','8','9']):
    result = bin_rep_to_rep_frac_(rem,dividend,max_digits,counting,rep=rep)
    carried = False
    if is_neg_bin_rep(sub_bin_rep(max_digits,length(result))):
        #longer result means we should round
        least_sig = getl(result)
        result = getr(result)
        d,_ = div_bin_rep(length(rep),position(rep,least_sig))
        if not is_neg_bin_rep(sub_bin_rep(b_two,d)): #round up
            big_endian = reverse(result)
            leading = b_zero
            while getl(big_endian) == getl(rep):
                big_endian = getr(big_endian)
                leading = add_bin_rep(leading,b_one)
            was_leading_one = getl(big_endian) == element(rep,b_one)
            result = bin_rep_to_rep(add_bin_rep(rep_to_bin_rep(result,rep=rep),b_one),rep=rep)
            result = rep_strip(reverse(result),remove=getl(rep))
            if not was_leading_one and getl(result) == element(rep,b_one): #carried into a zero
                if leading:
                    leading = sub_bin_rep(leading,b_one)
                else:
                    carried = True #carried into an integer part!
                    result = getr(result)
            while leading:
                leading = sub_bin_rep(leading,b_one)
                result = cell(getl(rep),result)
            result = reverse(result)
        else:
            result = reverse(rep_strip(reverse(result),remove=getl(rep)))
    return result,carried
```

With that, all the parts to convert float representations are in place, except for representing powers of two.
Fortunately, positive powers of two can be constructed in the binary integer representation.
```python
def pow2_bin_rep(exp): #exp must be positive or zero
    if not exp:
        return ['i']
    return cell('o',pow2_bin_rep(sub_bin_rep(exp,b_one)))
```
And with that, float representations can be converted back to decimal (or any base) fractions.
```python    
def float_rep_to_str(frac,max_digits=dec_precision,rep=['0','1','2','3','4','5','6','7','8','9'],point='.'):
    sig,exp = frac
    if is_neg_bin_rep(exp): 
        negative = is_neg_bin_rep(sig)
        if negative:
            sig = neg_bin_rep(sig)
        p = pow2_bin_rep(neg_bin_rep(exp))
        i,rem = div_bin_rep_signed(sig,p)
        int_part = bin_rep_to_rep(i,rep=rep)
        if int_part:
            max_digits = sub_bin_rep(max_digits,length(int_part))
            counting = True
        else:
            counting = False
        if is_neg_bin_rep(max_digits):
            frac_part = []
        else:
            frac_part,carried = bin_rep_to_rep_frac(rem,p,max_digits,counting,rep=rep)
            if carried:
                int_part = bin_rep_to_rep(add_bin_rep(i,b_one),rep=rep)
        str_rep = ''.join(reverse(frac_part+[point]+int_part))
        if negative:
            return '-' + str_rep
        else:    
            return str_rep
    else: # no fractional part
        int_part = mul_bin_rep_signed(sig,pow2_bin_rep(exp))
        return bin_rep_to_str(int_part)
```

This can be tested with the number from earlier.
```python
a = str_to_float_rep('1.24')
print(bin_rep_to_str(a[0]),'* 2^(',bin_rep_to_str(a[1]),')')
print(float_rep_to_str(a))
```
```plaintext
365983402422397504061 * 2^( -68 )
1.24
```

## Manipulation

The code in the previous section implements a way to approximate real numbers by an arbitrarily precise rational number in the form
$$ a \times 2^b $$
where $a$ and $b$ are both signed binary integers, and can convert to and from positional notation fractions in any base.
Now the task is to define basic mathematical operations on this float representation, so that more interesting calculations can be done.
This will be much less involved than [the manipulations in the post on integer math](/post/2021/03/31/math-as-an-algorithm/#manipulation), primarily because the works is largely done by the integer manipulations.

### Addition and subtraction

Two add two float representations $A = a_A2^{b_A}$ and $B = a_B2^{b_B}$, the representations must first be manipulated such that the exponents are the same.
This is analogous to aligning the decimal point when adding or subtraction decimal fractions.
If the significand is zero padded in the least significant side, which for binary numbers is the same as multiplying by two, the exponent should be reduced by one to represent the same rational number.
This means the number with the larger exponent can always have its significand multiplied by two (zero padded, or shifted to higher bits) enough times to reduce its exponent to the same value as the other number.
This leaves the significand and exponent of the result as integers, which is required by the float representation.
For example, if $b_A > b_B$ then:
$$ A \pm B = (a_A 2^{b_A - b_B} \pm a_B)2^{b_B} $$
This manipulation is easy in the binary representation.
```python
def shift_left_bin_rep(rep,val): #shift left in the big endian sense, anyway
    if not val:
        return rep
    return shift_left_bin_rep(cell('o',rep),sub_bin_rep(val,b_one))

def shift_left_bin_rep_signed(rep,val):
    if is_neg_bin_rep(rep):
        return neg_bin_rep(shift_left_bin_rep(neg_bin_rep(rep),val))
    else:
        return shift_left_bin_rep(rep,val)
```
With that, the significand of the two numbers can simply be added or subtracted using binary representation methods.
```python
def add_float_rep(a,b):
    a_sig,a_exp = a
    b_sig,b_exp = b
    exp_delta = sub_bin_rep_signed(a_exp,b_exp)
    if is_neg_bin_rep(exp_delta): # b is bigger
        b_sig = shift_left_bin_rep_signed(b_sig,neg_bin_rep(exp_delta))
        return add_bin_rep_signed(a_sig,b_sig),a_exp
    else: # a is bigger
        a_sig = shift_left_bin_rep_signed(a_sig,exp_delta)
        return add_bin_rep_signed(a_sig,b_sig),b_exp
    
def sub_float_rep(a,b):
    a_sig,a_exp = a
    b_sig,b_exp = b
    exp_delta = sub_bin_rep_signed(a_exp,b_exp)
    if is_neg_bin_rep(exp_delta): # b is bigger
        b_sig = shift_left_bin_rep_signed(b_sig,neg_bin_rep(exp_delta))
        return sub_bin_rep_signed(a_sig,b_sig),a_exp
    else: # a is bigger
        a_sig = shift_left_bin_rep_signed(a_sig,exp_delta)
        return sub_bin_rep_signed(a_sig,b_sig),b_exp
```

This works as expected for addition
```python
a = str_to_float_rep('-12')
b = str_to_float_rep('1.56')
c = add_float_rep(a,b)
print(float_rep_to_str(c))
```
```plaintext
-10.44
```
and for subtraction.
```python
a = str_to_float_rep('15.0')
b = str_to_float_rep('-4.5')
c = sub_float_rep(a,b)
print(float_rep_to_str(c))
```
```plaintext
19.5
```

### Multiplication and division

Multiplication of float representations is actually easier than addition and subtraction.
To multiply, simply multiply the significand and add the exponents.
$$ A \times B = a_Aa_B2^{b_A+b_B} $$
```python
def mul_float_rep(a,b):
    a_sig,a_exp = a
    b_sig,b_exp = b
    sig = mul_bin_rep_signed(a_sig,b_sig)
    exp = add_bin_rep_signed(a_exp,b_exp)
    return sig,exp
```

This works as expected.
```python
a = str_to_float_rep('32')
b = str_to_float_rep('1.000000000000000001')
c = mul_float_rep(a,b)
print(float_rep_to_str(c))
```
```plaintext
32.000000000000000032
```

Division can be handled in a similar way, but is a bit more complicated, since, unlike multiplication, the division of integers does not result in an integer.
$$ A \div B = \frac{a_A}{a_B}2^{b_A-b_B} $$
The binary representation already has a method `div_bin_rep` for returning an integer part $i$ and remainder $r$ of the ratio $a_A/a_B$.
$$ \frac{a_A}{a_B} = i + \frac{r}{a_B} $$
The integer part can be used directly, and the `bin_rep_to_bin_frac` developed to convert ratios less than one to binary fraction digits can be reused to find the fractional part.
The integer part and fractional part binary digits can be combined to get the result, with some care to ensure the final exponent is correct.
```python
def div_float_rep(a,b,max_bits=str_to_bin_rep('128')):
    a_sig,a_exp = a
    b_sig,b_exp = b
    sig,rem = div_bin_rep_signed(a_sig,b_sig)
    negative = is_neg_bin_rep(sig) or is_neg_bin_rep(rem)
    if negative:
        sig = neg_bin_rep(sig)
        rem = neg_bin_rep(rem)
    bits = sub_bin_rep(max_bits,length(sig))
    if is_neg_bin_rep(bits) or not rem:
        frac = []
    else:
        if is_neg_bin_rep(b_sig):
            b_sig = neg_bin_rep(b_sig)
        has_int_part = True if length(sig) else False
        frac = bin_rep_to_bin_frac(rem,b_sig,bits,has_int_part)
    exp = sub_bin_rep_signed(sub_bin_rep_signed(a_exp,b_exp),length(frac))
    sig = rep_strip(frac+sig)
    if negative:
        sig = neg_bin_rep(sig)
    return sig,exp
```

With division implemented, the rounding of the last digit when converting back to decimal fractions can be showcased.
```python
a = str_to_float_rep('2')
b = str_to_float_rep('3')
c = div_float_rep(a,b)
print(float_rep_to_str(c))
```
```plaintext
.66666666666666666667
```

### Maintaining precision

The division method for float representations is the only one that naturally limits the number of binary digits present in the significand, and this is only because the result of division (fractional numbers) can have infinitely long positional notation representations.
Addition, subtraction, and multiplication can all result in more bits of precision than desired, but these will never be infinite. 
Consider, for instance, adding a negative (small) power of two to a large power of two. 
```python
a = str_to_float_rep('1048576') # 2^20
print('2^20',a)
b = str_to_float_rep('0.03125') # 2^-5
print('2^-20',b)
c = add_float_rep(a,b)
print('sum',c)
print(float_rep_to_str(c))
```
```plaintext
2^20 (['i'], ['o', 'o', 'i', 'o', 'i'])
2^-20 (['i'], ['-', 'i', 'o', 'i'])
sum (['i', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'o', 'i'], ['-', 'i', 'o', 'i'])
1048576.03125
```
In the float representation, powers of two (even negative powers) can be represented with one bit of significand precision and the appropriate exponent.
When these are shifted to be added together, many zero bits appear in the middle of the result, increasing the number of bits required to represent the number significantly.
This number only requires 26 bits, so is well within the 70 bit default maximum, but this tendency to increase the number of bits required for an exact representation can present a serious problem, as operations on float representations with a large number of bits take correspondingly longer.

Recall that this float representation only aims to approximate real (irrational) numbers to a certain precision, and a solution becomes apparent: truncate these large results to the desired maximum precision, and continue calculating. 
This is a simple matter of removing the least significant bits, and adjusting the exponent appropriately.
```python
def max_bits_float_rep(a,max_bits=bin_precision):
    sig,exp = a
    negative = is_neg_bin_rep(sig)
    if negative:
        abssig = neg_bin_rep(sig)
    else:
        abssig = sig
    cmp = sub_bin_rep(max_bits,length(abssig))
    if is_neg_bin_rep(cmp):
        abssig = reverse(before(reverse(abssig),max_bits))
        if negative:
            sig = neg_bin_rep(abssig)
        else:
            sig = abssig
        exp = sub_bin_rep_signed(exp,cmp)
    return sig,exp
```

The impact of this truncation can be seen when applied to a number with more than roughly 20 decimal digits (70 binary bits) of precision.
```python
a = str_to_float_rep('100000000000000000000000000000000000000000000')
print('exact    ',float_rep_to_str(a))
b = max_bits_float_rep(a)
print('truncated ',float_rep_to_str(b))
print('ratio    ',float_rep_to_str(div_float_rep(b,a)))
```
```plaintext
exact     100000000000000000000000000000000000000000000
truncated  99999999999999999999980815305925381517737984
ratio     1.
```
Note that `str_to_float_rep` will always represent the integer part exactly, and approximate only the fractional part.
After applying `max_bits_float_rep` the number is reduced to 70 total binary bits.
The ratio of the result to the exact value is very nearly one.
In fact, to 20 significant figures, the ratio is one. 

### Convenience functions

The float representation is a very convenient one to do arbitrary mathematical operations in, as it approximates real numbers to any precision.
A possible exception to this is computing ratios of very large polynomials exactly, where binary representations of integers in the numerator and denominator can be used without worrying about precision.
Since the float representation is convenient, it makes sense to create some simply-named functions that operate on float representations.
Most of these are thin wrappers to the underlying algorithms, but with the added value of automatically truncating the results to the desired precision.

```python
def from_string(s,max_bits=bin_precision):
    return str_to_float_rep(s,max_bits=max_bits)
def to_string(a,rep=['0','1','2','3','4','5','6','7','8','9'],max_digits=dec_precision):
    return float_rep_to_str(a,rep=rep,max_digits=max_digits)
def add(a,b,max_bits=bin_precision):
    return max_bits_float_rep(add_float_rep(a,b),max_bits=max_bits)
def sub(a,b,max_bits=bin_precision):
    return max_bits_float_rep(sub_float_rep(a,b),max_bits=max_bits)
def mul(a,b,max_bits=bin_precision):
    return max_bits_float_rep(mul_float_rep(a,b),max_bits=max_bits)
def div(a,b,max_bits=bin_precision):
    return max_bits_float_rep(div_float_rep(a,b),max_bits=max_bits)
def neg(a):
    return neg_bin_rep(a[0]),a[1]
def abs(a):
    if is_neg_bin_rep(a[0]):
        return neg_bin_rep(a[0]),a[1]
    return a
```

Some small constant values will also be useful, similar to the binary representation case.
```python
zero = from_string('0')
one = from_string('1')
two = from_string('2')
three = from_string('3')
```

Comparison operators are straightforward.
```python
def eq(a,b):
    res = getl(sub(a,b))
    if not res:
        return True
    return False
def ge(a,b):
    res = getl(sub(a,b))
    if not res:
        return True
    elif is_neg_bin_rep(res):
        return False
    else:
        return True
def gt(a,b):
    res = getl(sub(a,b))
    if not res:
        return False
    elif is_neg_bin_rep(res):
        return False
    else:
        return True    
def le(a,b):
    res = getl(sub(a,b))
    if not res:
        return True
    elif is_neg_bin_rep(res):
        return True
    else:
        return False
def lt(a,b):
    res = getl(sub(a,b))
    if not res:
        return False
    elif is_neg_bin_rep(res):
        return True
    else:
        return False
```

And now some basic operations can be easily implemented, like computing integer powers of a float representation.
```python
def ipow(x,y):
    if eq(y,zero):
        return one
    return mul(x,ipow(x,sub(y,one)))

print(to_string(ipow(from_string('132'),from_string('3'))))
```
```plaintext
2299968
```

Factorials can also be easily implemented, and both will be useful for [approximating functions with infinite series](/post/2021/02/24/power-without-math-lib/).
```python
def factorial(x):
    if eq(x,zero):
        return one
    return mul(x,factorial(sub(x,one)))
    
print(to_string(factorial(from_string('16'))))
```
```plaintext
20922789888000
```

## Real math

Now that this custom math library can represent (approximations of all) real numbers, it is possible to do some actual mathematical operations.
Following the methodology covered in [a previous post](/post/2021/02/24/power-without-math-lib/) the manipulations developed here can be used to implement series approximations of important mathematical functions.
First I'll choose a float tolerance that is equal to the smallest value represented by the default 20 decimal digit (70 binary bits) of precision.
```python
small = from_string('.00000000000000000001')
```
Then the series expansion of the exponential function can be implemented.
$$ e^x = \sum_{n=0}^\infty \frac{x^n}{n!} $$
```python
def exp(z,ftol=small):
    if lt(z,zero):
        return div(one,exp(neg(z),ftol=ftol))
    res = one
    n = one
    while True:
        term = div(ipow(z,n),factorial(n))
        res = add(res,term)
        if lt(term,ftol):
            break
        n = add(n,one)
    return res
```
This can be used to compute $e$ itself as $e^1$.
```python
print(to_string(exp(one)))
```
```plaintext
2.7182818284590452353
```
Which is more precise than a typical 53-bit IEEE 754 double can store, and agrees well with [Wolfram Alpha's value](https://www.wolframalpha.com/input/?i=e%5E1).

The natural logarithm can be implemented [the same way as before](/post/2021/02/24/power-without-math-lib/#log)
```python
def log(x,q=two,ftol=small):
    if gt(x,q):
        r = zero
        while gt(x,q):
            x = div(x,q)
            r = add(r,one)
        return add(log(x,q=q,ftol=ftol),mul(r,log(q,q=q,ftol=ftol)))
    else:
        ratio = div(sub(x,one),add(x,one))
        res = zero
        i = one
        while True:
            term = mul(two,div(ipow(ratio,i),i))
            res = add(res,term)
            if lt(abs(term),ftol):
                break
            i = add(i,two)
        return res
```

Logarithms are particularly finicky when it comes to precision, because their series converge so slowly, and implementation in standard libraries --- even Python's math library --- are not as precise as they could be.
This can be shown by computing something mundane like $\log 57 / \log 7$.
In python the result is as follows.
```python
from math import log as math_log
print(math_log(57)/math_log(7))
```
```plaintext
2.0777173446560946
```

Using the algorithms developed here, the result comes out to be:
```python
print(to_string(div(log(from_string('57')),log(from_string('7')))))
```
```plaintext
2.0777173446560942614
```

Which has more digits, but note the last digit of the Python result (6) disagrees with the same place value as the 70-bit result (2) by more than rounding can account for.
To break the tie, consider the result from Wolfram Alpha
```plaintext
2.0777173446560942614193779943437364336390983385679283266498927304
```
which indicates that the custom math implementation is in fact more precise than Python's own math library. 
Granted, this precision comes with a significant speed penalty, so Python can be excused for this slight inaccuracy.

This post can be wrapped up with a function to compute arbitrary powers, again following the methodology from the [earlier post](/post/2021/02/24/power-without-math-lib/#pow).
```python
def pow(x,y):
    return exp(mul(y,log(x)))
```

This wraps up representing and manipulating real number representations with algorithms. 
Perhaps in a future post, I will show how to use this library of functions to do something perhaps a bit more interesting, like calculating $\pi$ very precisely.

