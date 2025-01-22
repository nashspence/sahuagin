# Use the Rust official image for building Rust code
FROM rust:latest as builder

# Install required tools for WebAssembly
RUN rustup target add wasm32-unknown-unknown && \
    cargo install wasm-pack

# Copy project files into the container
WORKDIR /app
COPY . .

# Build the project to WebAssembly and optimize the WASM binary
RUN wasm-pack build --target web && \
    mkdir -p /output && \
    cp pkg/*.wasm /output/

# Optimize the WebAssembly binary using binaryen
RUN apt-get update && apt-get install -y binaryen && \
    wasm-opt -O3 /output/*.wasm -o /output/optimized.wasm

# Runtime image
FROM debian:bullseye-slim as runtime

# Install WebAssembly runtime tools
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    socat && \
    curl -LO https://github.com/bytecodealliance/wasmtime/releases/download/v7.0.0/wasmtime-v7.0.0-x86_64-linux.tar.xz && \
    tar -xJf wasmtime-v7.0.0-x86_64-linux.tar.xz -C /usr/local/bin --strip-components=1 && \
    rm wasmtime-v7.0.0-x86_64-linux.tar.xz

# Expose port for remote debugging
EXPOSE 9229

# Copy optimized WASM from the builder stage
COPY --from=builder /output/optimized.wasm /app/optimized.wasm

# Set up remote debugging with Wasmtime
RUN apt-get install -y procps && \
    echo "alias debug-wasm='wasmtime run --debug /app/optimized.wasm'" >> /root/.bashrc

# Default command for debugging
CMD ["socat", "tcp-listen:9229,fork", "exec:/usr/local/bin/wasmtime --debug /app/optimized.wasm"]