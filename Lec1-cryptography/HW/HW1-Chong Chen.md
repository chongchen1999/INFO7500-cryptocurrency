# Homework 1 - Chong Chen

## 1. Find a collision in each of the hash functions below:  

### 1.1. H(x) = $x^2 \mod 9$, where x can be any integer  
**Answer**:  
Let $x_1 = 9$ and $x_2 = 18$. Then:  
\[ H(x_1) = H(x_2) = 0 \]  

### 1.2. H(x) = number of 0-bits in x, where x can be any bit string  
- **Note**: A "bit string" is simply a sequence of 0s and 1s.  
- **Example**: `01011011` is a bit string.  

**Answer**:  
Let $x_1 = \text{"10011"}$ and $x_2 = \text{"010111"}$. Then:  
\[ H(x_1) = H(x_2) = 2 \]  

### 1.3. H(x) = the three least significant bits of x, where x is a 32-bit integer  
- **Note**:  
  - "Least significant bits" refers to the binary digits on the far right-hand side.  
  - Numbers use **big-endian** encoding.  
  - Example:  
    - For the decimal number `384`, the two least significant digits are `84` (decimal).  
    - Similarly, the least significant bits for binary numbers are on the right-hand side.  

**Answer**:  
Let $x_1 = 1$ and $x_2 = 1 + 2^{30} = 1073741825$. Then:  
\[ H(x_1) = H(x_2) = 1 \]  

---

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

## 3. Protocol for Playing Rock-Paper-Scissors Over SMS

Alice and Bob want to play the game "[Rock-Paper-Scissors](https://en.wikipedia.org/wiki/Rock_paper_scissors)" asynchronously over SMS. To ensure fairness and prevent cheating, a cryptographic hash function-based protocol is proposed.  

### **Proposed Protocol**  
1. **Commit Phase**:  
   - Both Alice and Bob independently decide their move (`rock`, `paper`, or `scissors`).  
   - Each player generates a random secret string (e.g., a number or phrase).  
   - They concatenate their move with their secret string to create a "commitment".  
   - Each player computes the cryptographic hash of their commitment (e.g., using SHA-256).  
   - They send **only the hash** of their commitment to the other player via SMS.  

2. **Reveal Phase**:  
   - After both players have sent their hashes, they reveal their original moves and secret strings to each other.  
   - Each player verifies the other's move by checking that the hash of the revealed move and secret string matches the hash received in the Commit Phase.  

### **Why This Protocol Works**  
1. **Fairness**:  
   - Neither player can change their move after sending their hash in the Commit Phase.  
   - The hash ensures that the move is "locked in" without revealing it to the opponent.  

2. **Prevention of Cheating**:  
   - Since cryptographic hash functions are one-way, it is computationally infeasible to deduce the original move or secret string from the hash alone.  
   - This ensures that players cannot alter their moves after seeing their opponent's hash.  

3. **Transparency**:  
   - The Reveal Phase allows each player to verify the other's commitment and ensures the game is played honestly.  

4. **Asynchronous Play**:  
   - The protocol does not require both players to be available simultaneously. Each phase can be completed independently.  

By using this protocol, Alice and Bob can play Rock-Paper-Scissors fairly and securely, even over an asynchronous communication medium like SMS.
