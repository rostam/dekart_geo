#!/usr/bin/env bash
# Build a patched Dekart image that adds an "Import style" button (load a kepler
# style .json and rebind it to the current map's data). Builds the full image
# from a pinned source commit with import-style.patch applied.
#
#   ./build.sh                       # builds dekart-custom:local
# Then point the stack at it:
#   echo 'DEKART_IMAGE=dekart-custom:local' >> ../.env   # (the .env compose reads)
#   cd .. && ./dekart.sh restart
set -euo pipefail

REF="45b5b54e1206573fa703e8a08aeda57310e82c90"   # dekart main @ time of patch
IMAGE="dekart-custom:local"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# docker vs sudo docker
if docker info >/dev/null 2>&1; then DOCKER="docker"; else DOCKER="sudo docker"; fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Cloning dekart @ ${REF:0:12} ..."
git clone --quiet https://github.com/dekart-xyz/dekart.git "$WORK/dekart"
git -C "$WORK/dekart" checkout --quiet "$REF"

echo "==> Applying import-style.patch ..."
git -C "$WORK/dekart" apply "$HERE/import-style.patch"

echo "==> Building $IMAGE (frontend + backend; takes several minutes) ..."
$DOCKER build -t "$IMAGE" "$WORK/dekart"

echo "==> Done. Image: $IMAGE"
echo "    Enable it:  echo 'DEKART_IMAGE=$IMAGE' >> $(cd "$HERE/.." && pwd)/.env  &&  ../dekart.sh restart"
