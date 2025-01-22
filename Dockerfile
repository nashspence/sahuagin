# Use the Rust official image for building Rust code
FROM rust:latest as builder

# Install required tools for WebAssembly
RUN rustup target add wasm32-unknown-unknown && \
    cargo install wasm-pack

# Copy project files into the container
WORKDIR /app
COPY . .

# Build the project to WebAssembly with debug symbols
RUN wasm-pack build --target web --dev && \
    mkdir -p /output && \
    cp pkg/*.wasm /output/

# Runtime image
FROM debian:bullseye-slim as runtime

# Install WebAssembly runtime tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    tar \
    lldb-server && \
    WASMTIME_VERSION=$(curl -s https://api.github.com/repos/bytecodealliance/wasmtime/releases/latest | grep "tag_name" | cut -d '"' -f 4) && \
    curl -LO https://github.com/bytecodealliance/wasmtime/releases/download/$WASMTIME_VERSION/wasmtime-$WASMTIME_VERSION-x86_64-linux.tar.xz && \
    tar -xJf wasmtime-$WASMTIME_VERSION-x86_64-linux.tar.xz -C /usr/local/bin --strip-components=1 && \
    rm wasmtime-$WASMTIME_VERSION-x86_64-linux.tar.xz && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Expose port for remote debugging
EXPOSE 9229

# Copy debug-enabled WASM and source maps from the builder stage
COPY --from=builder /app/pkg/*.wasm /app/
COPY --from=builder /app/pkg/*.d.ts /app/
COPY --from=builder /app/pkg/*.js /app/

# Command to start lldb-server
CMD ["lldb-server", "platform", "--listen", "*:9229", "--server"]
