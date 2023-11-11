#!/bin/bash

install_docker() {
    echo "Installing Docker..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl enable --now docker
    echo "Docker installed successfully."
}

detect_architecture() {
    ARCH=$(uname -m)
    if [ "$ARCH" == "x86_64" ]; then
        VERSION="latest"
    elif [ "$ARCH" == "aarch64" ]; then
        VERSION="arm64v8"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
}

run_traffmonetizer() {
    if [ -z "$1" ]; then
        echo "Error: Please provide a token for traffmonetizer."
        exit 1
    fi

    TOKEN=$1

    echo "Running traffmonetizer Docker container..."
    sudo docker run -d --name tm --restart always traffmonetizer/cli_v2:$VERSION --token $TOKEN
}

install_docker
detect_architecture
echo "Using version: $VERSION"

if [ -z "$1" ]; then
    echo "Error: Please provide the traffmonetizer token as a command-line argument."
    exit 1
fi

run_traffmonetizer "$1"
