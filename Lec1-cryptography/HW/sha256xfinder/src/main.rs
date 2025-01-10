use sha2::{Digest, Sha256};
use rand::Rng;
use hex;

const ID: &str = "ED00AF5F774E4135E7746419FEB65DE8AE17D6950C95CEC3891070FBB5B03C78";
const TARGET_BYTE: u8 = 0x2F;

fn main() {
    // Convert the ID to a byte array.
    let id_bytes = hex::decode(ID).expect("Failed to decode ID");

    let mut rng = rand::thread_rng();

    loop {
        // Generate a random 256-bit value (32 bytes) as x.
        let mut x_bytes = [0u8; 32];
        rng.fill(&mut x_bytes);

        // Concatenate x and id to create x ◦ id.
        let mut concatenated = x_bytes.to_vec();
        concatenated.extend(&id_bytes);

        // Compute H(x ◦ id) using SHA-256.
        let hash = Sha256::digest(&concatenated);

        // Check if any byte in the hash is equal to TARGET_BYTE (0x2F).
        if hash.iter().any(|&byte| byte == TARGET_BYTE) {
            println!("Found x: {}", hex::encode(x_bytes));
            break;
        }
    }
}
