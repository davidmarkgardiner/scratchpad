```
echo "Performing actions based on image information..."
echo "ORIGINAL_IMAGE: $ORIGINAL_IMAGE"
echo "IMAGE_INFO: $IMAGE_INFO"

# Extract just the image/version part by removing anything before the first slash
IMAGE_INFO=$(echo "$ORIGINAL_IMAGE" | sed 's|^[^/]*/||')
echo "Pure image/version: $IMAGE_INFO"

# Login to ACR
oras login ${acr} -u 00000000-0000-0000-0000-000000000000 -p $(cat /token/acr-token)

# Check if image already exists in destination ACR
if oras manifest fetch --descriptor ${acr}/$IMAGE_INFO > /dev/null 2>&1; then
  echo "Checking if source and destination manifests match..."
  # Get manifests
  source_manifest=$(oras manifest fetch --insecure --descriptor container-registry.xxx.net/$IMAGE_INFO)
  dest_manifest=$(oras manifest fetch --descriptor ${acr}/$IMAGE_INFO)
  
  # Compare manifests
  if [[ "$source_manifest" == "$dest_manifest" ]]; then
    echo "Image already exists in destination with the same manifest. Skipping copy."
    exit 0
  else
    echo "Image exists in destination but manifests don't match. Will copy to update."
  fi
fi

# If we get here, the image either doesn't exist or has a different manifest
echo "Copying image from source to destination..."
oras cp --from-insecure container-registry.xxx.net/$IMAGE_INFO ${acr}/$IMAGE_INFO

# Verify the copy was successful
echo "Verifying copy operation..."
source_manifest=$(oras manifest fetch --insecure --descriptor container-registry.xxx.net/$IMAGE_INFO)
dest_manifest=$(oras manifest fetch --descriptor ${acr}/$IMAGE_INFO)

if [[ "$source_manifest" == "$dest_manifest" ]]; then
  echo "Image copied successfully, the 2 manifests match"
else
  echo "Error, Image has not been copied successfully, the 2 manifests don't match"
  exit 1
fi