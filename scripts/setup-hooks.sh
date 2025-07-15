#!/bin/bash

# Setup pre-commit hooks for show-coverage.nvim

set -e

echo "Setting up pre-commit hooks..."

# Check if pre-commit is installed
if ! command -v pre-commit &> /dev/null; then
    echo "pre-commit not found. Installing via pip..."
    pip install pre-commit
fi

# Install the pre-commit hooks
echo "Installing pre-commit hooks..."
pre-commit install

# Run pre-commit on all files to ensure everything is working
echo "Running pre-commit on all files..."
pre-commit run --all-files

echo "Pre-commit hooks setup complete!"
