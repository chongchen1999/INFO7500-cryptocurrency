from modal import Secret

# Create a secret
secrets = {
    "CHAINSTACK_USERNAME": "focused-fermi",
    "CHAINSTACK_PASSWORD": "unsaid-cleft-errant-ample-sister-garnet",
    "CHAINSTACK_URL": "33c7e6e3370a6b6c4e4dcf41f2746c59"
}

# Register the secret with Modal
Secret.from_dict("chainstack-credentials", secrets)
