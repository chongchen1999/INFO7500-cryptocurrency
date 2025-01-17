## Chapter 1: Introduction to Cryptography & Cryptocurrencies

### 1.1 Cryptographic Hash Function

**Collision‐resistance**: ​A hash function​ H​ is said to be collision resistant if it is infeasible to find​ ​two values, ​x​ and ​y​, such that ​x ​≠​ ​y​, yet ​H(x)​=​H(y)​.

**Hiding**.​ A hash function H is hiding if: when a secret value ​r​ is chosen from a probability distribution that has ​high min‐entropy​, then given ​H(r ‖ x)​ it is infeasible to find ​x​.
‖ denotes concatenation and high min‐entropy captures the intuitive idea that the distribution (i.e., random variable) is very spread out.

**Puzzle friendliness**.​ A hash function ​H ​is said to be puzzle‐friendly if for every possible n‐bit output value ​y​, if k is chosen from a distribution with high min‐entropy, then it is infeasible to find ​x​ such that H(k ‖ x) = y in time significantly less than ​$2​^n​$.

### 1.2 Hash Pointers and Data Structures

#### Hash Pointer:
Pointer: A reference to a block of data or a specific memory location.
Hash: A cryptographic hash (like SHA-256) of the data at that location.

### 1.3 Digital Signatures

#### Digital Signature Scheme

A digital signature scheme consists of the following three algorithms:

1. **Key Generation:**
   - `(sk, pk) := generateKeys(keysize)`
   - The `generateKeys` method takes a key size as input and generates a key pair.
     - **`sk` (Secret Key):** Kept private and used to sign messages.
     - **`pk` (Public Key):** Distributed publicly. Anyone with this key can verify the corresponding signature.

2. **Signing:**
   - `sig := sign(sk, message)`
   - The `sign` method takes a message and a secret key (`sk`) as input and produces a signature (`sig`) for the message under the given secret key.

3. **Verification:**
   - `isValid := verify(pk, message, sig)`
   - The `verify` method takes a message, a signature, and a public key as input. It returns a boolean value (`isValid`):
     - `true`: If the signature is valid for the message under the given public key.
     - `false`: Otherwise.

#### Properties

1. **Validity of Signatures:**
   - A valid signature must satisfy the following property:
     ```
     verify(pk, message, sign(sk, message)) == true
     ```

2. **Existential Unforgeability:**
   - It must be computationally infeasible for an adversary to forge a valid signature for any message, even if they have access to multiple valid signatures generated using the private key (`sk`).

### 1.4 Public Keys as Identities

### 1.5 A Simple Cryptocurrency

