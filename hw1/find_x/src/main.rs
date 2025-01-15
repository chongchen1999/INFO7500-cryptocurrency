use hex;
use rand::Rng;
use sha2::{Digest, Sha256};

fn main() {
    // println!("{}", check_contain());
    let id_hex_string = "ED00AF5F774E4135E7746419FEB65DE8AE17D6950C95CEC3891070FBB5B03C78";
    const TARGET_BYTE: u8 = 0x2F;

    let id_hex = hex::decode(id_hex_string).expect("Failed to decode hexadecimal string");

    // Initialize the random number generator
    let mut rng = rand::thread_rng();

    loop {
        // Generate a random 32-byte array
        let mut random_bytes = [0u8; 32];
        rng.fill(&mut random_bytes);

        // Concatenate the random bytes and the ID
        let mut concatenated_input = random_bytes.to_vec();
        concatenated_input.extend_from_slice(&id_hex);

        // Compute the SHA-256 hash of the concatenated input
        let hash_result = Sha256::digest(&concatenated_input);

        // Check if the hash contains the target byte
        if hash_result.contains(&TARGET_BYTE) {
            // Convert the random bytes to a hexadecimal string
            let random_bytes_hex = hex::encode(random_bytes).to_uppercase();
            println!("Found matching x: {}", random_bytes_hex);
            break;
        }
    }
}