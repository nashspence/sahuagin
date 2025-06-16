FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip sudo postgresql postgresql-contrib \
    postgresql-plpython3-16 \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir pytest
WORKDIR /workspace
COPY . /workspace
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["pytest", "-v"]
