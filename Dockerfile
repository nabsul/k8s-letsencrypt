FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y curl vim nano certbot && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod 755 kubectl && mv kubectl /usr/local/bin/ && \
    rm -rf /var/lib/apt/lists/*

CMD tail -f /dev/null
