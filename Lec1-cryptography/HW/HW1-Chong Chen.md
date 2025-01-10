# Homework 1 - Chong Chen

1. Find a collision in each of the hash functions below:  
   1. H(x) \= x2 mod 9, where x can be any integer  
   2. H(x) \= number of 0-bits in x, where x can be any bit string  
      1. Note: a “bit string” is simply a sequence of 0s and 1s  
      2. For example, 01011011 is a bit-string  
   3. H(x) \= the three least significant bits of x, where x is a 32-bit integer.  
      1. Note: “least significant bits” is the same as “least significant digits” but binary instead of decimal.  
      2. For example, for decimal number 384, what are the two least significant digits? 84\.  
      3. Assume the least significant bits are on the right hand side, which means the number uses “big-endian” encoding, rather than “little endian” encoding. Read more about endianness [here](https://en.wikipedia.org/wiki/Endianness).  
         1. The number 384 is the big-endian representation of three hundred, eighty-four.  
         2. The number 483 is the little-endian representation of three hundred, eighty-hour.

   

3. Alice and Bob want to play the game called “[rocks-paper-scissors](https://en.wikipedia.org/wiki/Rock_paper_scissors)” over SMS text. Their game play is asynchronous in the sense that they can’t expect the other person to be available at a certain time or within a certain time window. Design a protocol that enables Alice and Bob to play the game fairly and prevents the possibility of cheating. Provide a detailed explanation of the mechanism and why it works. An answer with insufficient detail will not receive credit. You should only need to use cryptographic hash functions to solve this problem. Keep the solution simple.

