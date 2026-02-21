#!/bin/bash

# Set up environment variables
set -e

echo "Setting up environment..."

# Install dependencies
echo "Installing dependencies..."

# Install Rust
echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

source $HOME/.cargo/env

# Build Core library
echo "Building Core library..."
cd Core
cargo build --release
cd ..

echo "CI post-clone script completed successfully!"
