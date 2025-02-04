# Blockchain Explorer Tooling Setup

## Docker
**Dockerfile:**
```dockerfile
# Use an official Python runtime as a parent image
FROM python:3.9

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container
COPY . .

# Run a simple Python script
CMD ["python", "-c", "print('Hello from Docker!')"]
