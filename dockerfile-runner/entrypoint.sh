#!/bin/bash
set -e

##
## FeatherPanel Dockerfile Runner
## github.com/nexustechpro2/yolks
##

CONTAINER_DIR="/home/container"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-Dockerfile}"
IMAGE_NAME="user-app-$(hostname | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')"
PORT="${SERVER_PORT:-8080}"

echo "------------------------------------------------"
echo " FeatherPanel Dockerfile Runner"
echo " github.com/nexustechpro2/yolks"
echo "------------------------------------------------"
echo ""

# Check Dockerfile exists
if [ ! -f "${CONTAINER_DIR}/${DOCKERFILE_PATH}" ]; then
    echo "[ERROR] No Dockerfile found at: ${CONTAINER_DIR}/${DOCKERFILE_PATH}"
    echo "[INFO]  Upload your project files via SFTP."
    echo "[INFO]  Make sure your Dockerfile is present in the root of your project."
    exit 1
fi

echo "[INFO] Dockerfile found: ${CONTAINER_DIR}/${DOCKERFILE_PATH}"

# Load .env file if present
if [ -f "${CONTAINER_DIR}/.env" ]; then
    echo "[INFO] Loading .env file..."
    set -a
    source "${CONTAINER_DIR}/.env"
    set +a
    echo "[INFO] .env loaded successfully."
fi

echo ""

# Build the image
echo "[BUILD] Starting image build..."
echo "[BUILD] Image name: ${IMAGE_NAME}"
echo "[BUILD] Build args: ${BUILD_ARGS:-none}"
echo ""

# Register current UID so tools can resolve the current user
if ! id "$(id -u)" &>/dev/null 2>&1; then
    echo "container:x:$(id -u):$(id -g)::/home/container:/bin/sh" >> /etc/passwd
    echo "[INFO] Registered UID $(id -u) in /etc/passwd"
fi

buildah bud \
    --isolation=chroot \
    --storage-driver=vfs \
    --no-pivot \
    --format=docker \
    --tag "${IMAGE_NAME}" \
    ${BUILD_ARGS:-} \
    --file "${CONTAINER_DIR}/${DOCKERFILE_PATH}" \
    "${CONTAINER_DIR}"

echo ""
echo "[INFO] Build complete."
echo ""

# Remove any existing container with same name
podman rm -f "${IMAGE_NAME}-container" 2>/dev/null || true

# Pull built image from buildah into podman
buildah push \
    --storage-driver=vfs \
    "${IMAGE_NAME}" \
    "containers-storage:${IMAGE_NAME}"

echo "[INFO] Starting container on port ${PORT}..."
echo ""

# Run with podman
# Wings already enforces CPU/RAM limits at the container level
# We pass the port and all environment variables the user set
exec podman run \
    --rm \
    --name "${IMAGE_NAME}-container" \
    --network=slirp4netns \
    --storage-driver=vfs \
    -p "${PORT}:${PORT}" \
    -e "PORT=${PORT}" \
    -e "SERVER_PORT=${PORT}" \
    ${USER_ENV:-} \
    ${RUN_ARGS:-} \
    "${IMAGE_NAME}" \
    ${RUN_CMD:-}
