FROM --platform=linux/amd64 debian:bookworm

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_VERSION
RUN apt update && \
    apt dist-upgrade -y && \
    apt install -y \
        autoconf \
        automake \
        build-essential \
        cmake \
        curl \
        git \
        libboost-program-options-dev \
        libboost-system-dev \
        libboost-test-dev \
        libboost-thread-dev \
        libbz2-dev \
        libeigen3-dev \
        liblzma-dev \
        libudev-dev \
        pkg-config \
        python3 \
        sudo \
        zlib1g-dev && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash && \
    bash -c "export NVM_DIR=\${HOME}/.nvm && \
        source \${NVM_DIR}/nvm.sh && \
        npm config -g set cache /tmp/.npm && \
        nvm cache clear"
