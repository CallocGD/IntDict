# IntDict
based off aiolib's [multidict library](https://github.com/aio-libs/multidict) but the keys are strictly used for integers

## Why develop such a useless library?
- This is going to be for something much bigger than itself but I'll give you a hint for now: gdpy is getting redone and I have [another project](https://github.com/callocgd/Robdantic) uploaded as a second concept.
- Python's SipHash functions can be easily improved upon
- It is meant to be 100% compatable with Both Cython & Python (Rust was the original idea for a backend but skipped out on it due to difficulty) 
- When Validating through thousands of integers in a key/value pattern it is a better idea to store it as an integer rather than a string since it's faster to hash it up.
- The code is mostly Cython and should be easy for a developer to compile due to it's simpleness. Copy and Pasting the Stubfiles into other projects should be straight forward for anyone to do.

## Advantages
- Good for extreme iteration and Integer valdiation
- Minimal capacity in memory
- Faster than Python's Siphash functions
- As Far as I am aware there's no collisions...

## Disadantages
- Linear Search time in some areas
- Bad for extremely large dictionaries

## Pull Requests Accepted
- I encourage anybody to hop in and take what I've forked from multidict and make things better...


 
