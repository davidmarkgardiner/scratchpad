#!/bin/bash

# Sample image with problematic characters
IMAGE="my.registry.com/Nginx/1.19.0_WithSpecial@Characters!"
echo "Original image: $IMAGE"

# Step 1: Remove repository prefix (everything before .com/)
STEP1=$(echo "$IMAGE" | sed -E 's|^.*\.com/||')
echo "Step 1 (Remove prefix): $STEP1"

# Step 2: Replace / with -
STEP2=$(echo "$STEP1" | sed 's|/|-|g')
echo "Step 2 (Replace / with -): $STEP2"

# Step 3: Convert to lowercase
STEP3=$(echo "$STEP2" | tr '[:upper:]' '[:lower:]')
echo "Step 3 (Lowercase): $STEP3"

# Step 4: Replace special characters with hyphens
STEP4=$(echo "$STEP3" | sed -E 's|[^a-z0-9-]|-|g')
echo "Step 4 (Replace special chars): $STEP4"

# Step 5: Replace trailing hyphen with '1' if present
STEP5=$(echo "$STEP4" | sed -E 's|-$|1|')
echo "Step 5 (Fix trailing hyphen): $STEP5"

# Final result as it would appear in Kubernetes
FINAL="image-process-${STEP5}"
echo -e "\nFinal Job name: $FINAL"

# Verify RFC 1123 compliance
echo -e "\nVerifying RFC 1123 compliance..."

# Check if name contains only lowercase alphanumeric characters and hyphens
if [[ $FINAL =~ ^[a-z0-9-]+$ ]]; then
  echo "✅ Name is RFC 1123 compliant (only lowercase alphanumeric and hyphens)"
else
  echo "❌ Name is NOT RFC 1123 compliant"
fi

# Check if name starts and ends with alphanumeric
if [[ $FINAL =~ ^[a-z0-9].*[a-z0-9]$ ]]; then
  echo "✅ Name starts and ends with alphanumeric character"
else
  echo "❌ Name does not start and end with alphanumeric character"
fi

# Check length (DNS labels must be 63 characters or less)
if [[ ${#FINAL} -le 63 ]]; then
  echo "✅ Name length is valid (${#FINAL} characters, max 63)"
else
  echo "❌ Name length exceeds 63 characters (${#FINAL})"
fi 