# Homework 1

Submit your answers in a simple text file or as a link to a google doc with public access.

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

         

2. Implement a program to find an x such that H (x ◦ id) ∈ Y where  
   1. H \= SHA-256  
   2. id \= 0xED00AF5F774E4135E7746419FEB65DE8AE17D6950C95CEC3891070FBB5B03C78  
   3. Y is the set of all 256 bit values that have some byte with the value 0x2F.  
   4. Assume SHA-256 is puzzle-friendly. Your answer for x must be in hexadecimal.   
   5. Here’s a useful link for understanding binary encoding, decimal encoding, and hex encoding: [https://www.rapidtables.com/convert/number/hex-to-decimal.html](https://www.rapidtables.com/convert/number/hex-to-decimal.html)  
   6. You must use a systems language like Java, Rust, or Golang.  
      1. If you use Rust, use the following Rust crates:  
         1. [https://crates.io/crates/hex](https://crates.io/crates/hex)  
         2. [https://crates.io/crates/sha2](https://crates.io/crates/sha2)   
         3. [https://crates.io/crates/rand](https://crates.io/crates/rand)  
   7. **Caution**:    
      1. The notation “x ◦ id” means the byte array x concatenated with the byte array id. For example, 11110000 ◦ 10101010 is the byte array 1111000010101010\.  
      2. The following two code segments are not equivalent:

| INCORRECT | CORRECT |
| :---- | :---- |
| let id\_hex \= “1D253A2F"; if id\_hex.contains("1D") {    return; } | let id\_hex \= “1D253A2F"; let decoded \= hex::decode(id\_hex).expect("Decoding failed"); let u \= u8::from(29); //29 in decimal is 0x1d in hex if decoded.contains(\&u) {    return; }  |

   

      The second code segment above is the correct way to check whether 0x1D is a byte in 0x1D253A2F. Remember that hex format is only a way to represent a byte sequence in a human readable format. You should never perform operations directly on hex-string representations. Instead, you should first convert hex-strings into byte arrays, then perform operations on the byte arrays directly, and then convert the final byte array into a hex format when giving your answer. Performing operations directly on the hex strings is incorrect.

   

3. Alice and Bob want to play the game called “[rocks-paper-scissors](https://en.wikipedia.org/wiki/Rock_paper_scissors)” over SMS text. Their game play is asynchronous in the sense that they can’t expect the other person to be available at a certain time or within a certain time window. Design a protocol that enables Alice and Bob to play the game fairly and prevents the possibility of cheating. Provide a detailed explanation of the mechanism and why it works. An answer with insufficient detail will not receive credit. You should only need to use cryptographic hash functions to solve this problem. Keep the solution simple.

