# Use the latest foundry image
FROM ghcr.io/foundry-rs/foundry

# Switch to root to install packages
USER root

# Copy our source code into the container
WORKDIR /app

# Install Node.js and pnpm
RUN apt-get update && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g pnpm && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
 
# Build and test the source code
COPY . .

ENV FOUNDRY_DISABLE_NIGHTLY_WARNING=true

RUN pnpm install
RUN forge soldeer install
RUN forge build
RUN forge test