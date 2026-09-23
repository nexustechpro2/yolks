FROM ubuntu:24.04

LABEL maintainer="nexustechpro2"
LABEL org.opencontainers.image.source="https://github.com/nexustechpro2/yolks"
LABEL org.opencontainers.image.description="Dockerfile runner egg for FeatherPanel"

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    buildah \
    podman \
    fuse-overlayfs \
    slirp4netns \
    uidmap \
    tini \
    curl \
    ca-certificates \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Configure buildah/podman storage — vfs works inside Wings without privileges
RUN mkdir -p /etc/containers && cat > /etc/containers/storage.conf <<'EOF'
[storage]
driver = "vfs"
runroot = "/run/containers/storage"
graphroot = "/var/lib/containers/storage"

[storage.options.vfs]
ignore_chown_errors = "true"
EOF

# Configure containers for chroot isolation + cgroupfs
RUN cat > /etc/containers/containers.conf <<'EOF'
[containers]
default_capabilities = [
    "CHOWN",
    "DAC_OVERRIDE",
    "FOWNER",
    "FSETID",
    "KILL",
    "NET_BIND_SERVICE",
    "SETGID",
    "SETPCAP",
    "SETUID",
]

[engine]
cgroup_manager = "cgroupfs"
events_logger = "file"

[network]
network_backend = "slirp4netns"
EOF

# Configure registries
RUN cat > /etc/containers/registries.conf <<'EOF'
[registries.search]
registries = ["docker.io", "ghcr.io", "quay.io"]

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF

# Set up subuid/subgid for root so buildah can map users inside builds
RUN echo "root:100000:65536" >> /etc/subuid \
    && echo "root:100000:65536" >> /etc/subgid

# Working directory — Wings mounts user files here
RUN mkdir -p /home/container
WORKDIR /home/container

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Buildah env vars
ENV BUILDAH_ISOLATION=chroot
ENV STORAGE_DRIVER=vfs
ENV BUILDAH_FORMAT=docker

RUN echo "container:x:999:999::/home/container:/bin/sh" >> /etc/passwd \
    && echo "container:x:999:" >> /etc/group \
    && echo "container:100000:65536" >> /etc/subuid \
    && echo "container:100000:65536" >> /etc/subgid

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]

