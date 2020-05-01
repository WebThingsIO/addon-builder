FROM debian:buster

ARG DEBIAN_FRONTEND=noninteractive
ARG NODE_VERSION
RUN apt update && \
    apt dist-upgrade -y && \
    apt install -y \
        autoconf \
        automake \
        build-essential \
        curl \
        git \
        libudev-dev \
        pkg-config \
        python \
        sudo && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.2/install.sh | bash && \
    bash -c "export NVM_DIR=\${HOME}/.nvm && \
        source \${NVM_DIR}/nvm.sh && \
        nvm install ${NODE_VERSION} && \
        nvm use ${NODE_VERSION} && \
        npm config -g set unsafe-perm true && \
        nvm install-latest-npm && \
        nvm cache clear"
