#!/bin/bash

# Install Rust and Cargo
echo "Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Source the environment
source ~/.cargo/env

# Verify installation
echo "Rust version:"
rustc --version
echo "Cargo version:"
cargo --version

# Install additional components
rustup component add clippy rustfmt

echo "Rust installation complete!"
echo "You may need to restart your terminal or run: source ~/.cargo/env"