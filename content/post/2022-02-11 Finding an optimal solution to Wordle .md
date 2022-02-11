---
title: 'A possible optimal solution to Wordle'
date: '2022-02-11'
categories: 
  - Math
  - Programming
  - Games
description: Using probability and simulation to build an optimal solution to the game Wordle
slug: optimal-wordle-solution
toc: true
---

At this point, probably everyone has heard of the game [Wordle](https://www.nytimes.com/games/wordle/index.html) where one has six guesses to determine a secret five letter word.
Each time you guess, the letters are colored to represent the following:

1. Gray --- the letter is not in the word.
2. Orange --- the letter is in the word, but not at this position.
3. Green --- the letter is in the word at this position.

There are lots of strategies floating around for how to play this game optimally, from looking at character distributions at different positions and picking words with common characters in those positions, to using good old-fashioned intuition.
Here, I'll describe a solution that can be summarized as follows: the optimal word to guess is the word that results in the fewest possible words remaining, on average.

## Paring down a word list

Each stage of the game, provides the player with more information on the letters in the secret word.
Given a guess, there is then a finite set of $3^5 = 243$ pieces of information that could be received, corresponding to the different possible patterns of three colors in five slots. 
The possible remaining words can then be pared down according to the information.
All that remains is to represent the game state, and write an algorithm to perform this operation.

Each word can be described as a string, which itself can be thought of as an array or list of characters. 
I found it convenient to represent the wordlist as a 2D Numpy array of characters, and words as 1D Numpy arrays of characters.
Starting from a word list of five letter strings called `words` the master wordlist `wl` can be generated:
```python
import numpy as np
wl = np.asarray([list(w) for w in words])
```
The information given by the game for each guess could be represented by a length five list (or tuple), each element representing a position in the guessed word, using the numbers 1, 2, 3 for gray, orange, green.
```python
info = (1,1,1,1,1) #all gray is actually a lot of information!
```
Now, given some `guess` word as a 1D Numpy array, `wl` word list as 2D Numpy array, and `info` information tuple, a function can be written to generate a mask where each index is a boolean value representing whether the word remains in the word list after the information is taken into account.
```python
def gen_mask(guess,info,wl=wl):
    info = np.asarray(info)
    mask = np.ones(wl.shape[0], dtype=bool)
    for i,(g,inf) in enumerate(zip(guess,info)):
        if inf == 1:
            if np.count_nonzero(guess[info==3] == g) >= 1:
                #wordle grays out a letter if it's marked green elsewhere but doesn't go in that slot
                mask = np.logical_and(mask,wl[:,i] != g)
                #if it could be elewhere it might be orange...
            else:
                mask = np.logical_and(mask,np.all(wl != g,axis=1))
        elif inf == 2:
            mask = np.logical_and(mask,np.logical_and(np.any(wl == g,axis=1),wl[:,i] != g))
        elif inf == 3:
            mask = np.logical_and(mask,wl[:,i] == g)
        else:
            raise Exception(f'Invalid information: {inf}')
    return mask
```
Note: in testing this, I discovered that, as the comments suggest, Wordle will color letters gray instead of orange if the letter is present elsewhere in the word but already marked green. 
I'm not sure what happens if the letter appears twice in a word but only one location is marked green!

Using the `gen_mask` function to `get_remaining` words is straightforward:
```python
def get_remaining(guess,info,wl=wl):
    return wl[gen_mask(guess,info,wl=wl)]
```
As before, the `wl` word list is made an optional keyword, for future steps where the word list is a subset of all possible options.

This `gen_mask` function can also be used to efficiently calculate how many words remain (as a fraction of possible words) after a guess and its information:
```python
def frac_remaining(guess,info,wl=wl):
    m = gen_mask(guess,info,wl=wl)
    return np.count_nonzero(m)/wl.shape[0]
```
For a guess $g$, word list $W$, and information $i$, this `frac_remaining` function will be mathematical function $R(g, i \\,|\\, W)$ giving the fraction of the word list remaining after obtaining information about a guess.

## Averaging over unknown outcomes

All the player can choose is their guess, and then the game provides one of 243 possible sets of information.
Therefore, in evaluating each guess, one should consider the average outcome of receiving any information $R(g \\,|\\, W)$.
One might be tempted to assume all information is equally likely but there are two subtle points to consider.

1. If information has already been obtained (e.g. 'A' is in position 1), or even if the word list has some constraints ('Q' is always followed by 'U'), certain information for certain words can be impossible.
Both of these cases would result in remaining fractions of zero, which will be convenient.
2. If two pieces of information result in different remaining fractions, their relative probability is the ratio of their remaining fractions.
I.E. with all words being equally likely, information leaving two possible words is twice as likely as information leaving one possible word. 

What is desired, then, is an average of the remaining fraction over the possible information, weighted by the probability of receiving that information. 
Probability of receiving information for a guess is proportional to the remaining fraction per point two, so the expression to calculate is:

$$
R(g \\,|\\, W) = \left( \sum_{i \in I} R(g, i \\,|\\, W)^2 \right) \left( \sum_{i \in I} R(g, i \\,|\\, W) \right)^{-1}
$$

where the first part is a weighted sum, and the second part is the normalization, since $R(g, i \\,|\\, W)$ is not normalized to sum to 1 over all possible information.

Doing this in python is perhaps more straightforward than the math, if one leverages `itertools` for the loop over information, and `functools` to simplify some of the function calls.
```python
import itertools as it
import functools as ft

def avg_frac_remaining(guess,wl=wl):
    info = it.product(*[[1,2,3] for i in range(5)])
    func = ft.partial(frac_remaining,guess,wl=wl)
    rem = [func(i) for i in info]
    return np.sum(np.square(rem))/np.sum(rem)
```

### Aside: entropy and information

I've seen [other approaches](https://www.youtube.com/watch?v=v68zYyaEmEA) treat this same problem with information theory, and aimed to pick the outcome with maximal information (entropy) using an expression analogous to:
$$
-\sum_{i \in I} P(g, i \\,|\\, W) \log P(g, i \\,|\\, W)
$$
where the $P(g, i \\,|\\, W)$ is the probability of receiving some information for a guess given a word list.
The author choose to define this function the same as $R(g, i \\,|\\, W)$, which is curious, because $R$ is not normalized due to the different information cases having overlap in the words that might remain. 
This likely means that the combination of a guess and information is a bad basis for calculating entropy, and that this approach is flawed.
As it turns out, maximizing the expectation of the negative logarithm of a number is equivalent to minimizing the expectation of the same number, which is equivalent the approach I've taken here.

## Choosing the (next) best guess

Using the `avg_frac_remaining` the remaining words left after averaging over all possible information can be calculated for each word in the list.
```python
import multiprocessing as mp

with mp.Pool(12) as p:
    func = ft.partial(avg_frac_remaining,parallel=False)
    rem = p.map(func,wl)
```
With this methodology, the next best guess is the one with the fewest remaining words:
```python
guess = wl[np.argmin(rem)]
```
which happens to be RAISE, to start, if using the list of words Wordle considers to be possible answers.

If one enters RAISE and receives information (gray, green, gray, green, green), this can be used to derive a new list of possible words:
```python
wl2 = get_remaining(guess,[1,3,1,3,3])
```
where we find there are only 4 possible words remaining!

Continue with this approach by calculating the average remaining fractions for each new potential guess:
```python
rem2 = []
for g in wl2:
    rem2.append(f:=avg_frac_remaining(g,wl=wl2))
    print(g,f)
```
```plaintext
['l' 'a' 'p' 's' 'e'] 0.28
['c' 'a' 'u' 's' 'e'] 0.44
['p' 'a' 'u' 's' 'e'] 0.28
['m' 'a' 's' 's' 'e'] 0.73
['f' 'a' 'l' 's' 'e'] 0.44
```
LAPSE is chosen as the next guess, giving information (gray,green,orange,green,green), which identifies PAUSE as the correct word in three tries!

## Evaluating the performance

RAISE as a first guess is consistent with some other treatments of optimal Wordle strategies, but is certainly not a unanimous choice.
What is clear is that RAISE as a first choice leaves the lowest average of sixty words to sort through out of several thousand, and often ends up with far fewer.

The real metric to consider is how many moves any solution takes to find real Wordle answers.
This can be evaluated by having the algorithm play a thousand games, and simply tracking how many guesses are required to get the right answer.
```python
def evaluate(num=1000):
    solution_steps = []
    for word in wl[:num]:
        print(f'Word {word}')
        wl_n = wl
        rem_n = rem
        i = 0;
        with mp.Pool(12) as p:
            while True:
                i = i+1
                guess_n = wl_n[np.argmin(rem_n)]
                print(f'Guess {guess_n}')
                if np.all(guess_n == word):
                    print(f'Solved in {i}!')
                    solution_steps.append(i)
                    break
                #simulate wordle providing information on the guess
                info = [3 if g == w else 2 if g in word else 1 for g,w in zip(guess_n,word)]
                print(f'Info {info}')
                wl_n = get_remaining(guess_n,info,wl=wl_n)
                print(f'Rem: {len(wl_n)}')
                func = ft.partial(avg_frac_remaining,wl=wl_n,parallel=False)
                rem_n = p.map(func,wl_n)
    return solution_steps
```

Plotting the result as a histogram shows that all words were guessed in at most six guesses, with most being guessed in three guesses.
The average number of guesses required here, using the list of possible Wordle words as the word list, was 3.4.

{{< figure src="/images/wordle_num_guesses.png" class="center" >}}
