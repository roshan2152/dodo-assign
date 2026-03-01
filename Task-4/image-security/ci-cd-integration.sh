#!/bin/bash
# CI/CD Pipeline Integration for Image Security
# This script shows how to integrate image scanning and signing in your build pipeline

# =============================================================================
# Step 1: Scan image for vulnerabilities using Trivy
# =============================================================================
scan_image() {
  local image=$1
  local severity=${2:-"HIGH,CRITICAL"}
  
  echo "Scanning image: $image"
  
  # Install Trivy if not present
  if ! command -v trivy &> /dev/null; then
    echo "Installing Trivy..."
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
    sudo apt-get update
    sudo apt-get install trivy -y
  fi
  
  # Run Trivy scan
  trivy image --severity "$severity" --exit-code 1 "$image"
  
  if [ $? -ne 0 ]; then
    echo "❌ Scan failed: Vulnerabilities found"
    return 1
  fi
  
  echo "✅ Scan passed"
  return 0
}

# =============================================================================
# Step 2: Sign image using Cosign
# =============================================================================
sign_image() {
  local image=$1
  local signing_key=${2:-"cosign.key"}
  
  echo "Signing image: $image"
  
  # Install Cosign if not present
  if ! command -v cosign &> /dev/null; then
    echo "Installing Cosign..."
    curl -L https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 -o cosign
    chmod +x cosign
    sudo mv cosign /usr/local/bin/
  fi
  
  # Create signing key if it doesn't exist
  if [ ! -f "$signing_key" ]; then
    echo "Creating signing key..."
    cosign generate-key-pair
  fi
  
  # Sign the image
  cosign sign --key cosign.key "$image"
  
  echo "✅ Image signed"
  return 0
}

# =============================================================================
# Step 3: Verify image signature
# =============================================================================
verify_image() {
  local image=$1
  local public_key=${2:-"cosign.pub"}
  
  echo "Verifying image signature: $image"
  
  cosign verify --key "$public_key" "$image"
  
  if [ $? -eq 0 ]; then
    echo "✅ Image signature verified"
    return 0
  else
    echo "❌ Image signature verification failed"
    return 1
  fi
}

# =============================================================================
# Step 4: Generate SBOM (Software Bill of Materials)
# =============================================================================
generate_sbom() {
  local image=$1
  local output=${2:-"sbom.json"}
  
  echo "Generating SBOM for: $image"
  
  # Install Syft if not present
  if ! command -v syft &> /dev/null; then
    echo "Installing Syft..."
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
  fi
  
  # Generate SBOM in SPDX format
  syft "$image" -o spdx-json > "$output"
  
  echo "✅ SBOM generated: $output"
  return 0
}

# =============================================================================
# Step 5: Check image signature before deployment
# =============================================================================
check_deployment_image() {
  local image=$1
  local public_key=${2:-"cosign.pub"}
  
  echo "Pre-deployment check for: $image"
  
  # Verify image exists
  docker pull "$image" &> /dev/null
  if [ $? -ne 0 ]; then
    echo "❌ Image not found: $image"
    return 1
  fi
  
  # Verify signature
  cosign verify --key "$public_key" "$image" &> /dev/null
  if [ $? -ne 0 ]; then
    echo "❌ Image signature not valid"
    return 1
  fi
  
  echo "✅ Image ready for deployment"
  return 0
}

# =============================================================================
# Usage in GitHub Actions / GitLab CI / Jenkins
# =============================================================================
# Example GitHub Actions workflow:
#
# name: Security Scan & Sign
# on: [push, pull_request]
# jobs:
#   security:
#     runs-on: ubuntu-latest
#     steps:
#     - uses: actions/checkout@v2
#     
#     - name: Build Image
#       run: docker build -t myapp:${{ github.sha }} .
#     
#     - name: Push to Registry
#       run: docker push myapp:${{ github.sha }}
#     
#     - name: Scan Image
#       run: |
#         ./ci-cd-integration.sh
#         scan_image "myapp:${{ github.sha }}"
#     
#     - name: Sign Image
#       run: |
#         ./ci-cd-integration.sh
#         sign_image "myapp:${{ github.sha }}"
#       env:
#         COSIGN_EXPERIMENTAL: 1
#     
#     - name: Generate SBOM
#       run: |
#         ./ci-cd-integration.sh
#         generate_sbom "myapp:${{ github.sha }}"

# =============================================================================
# Main execution (if script is run directly)
# =============================================================================
if [ "$1" != "" ]; then
  case "$1" in
    scan)
      scan_image "$2" "$3"
      ;;
    sign)
      sign_image "$2" "$3"
      ;;
    verify)
      verify_image "$2" "$3"
      ;;
    sbom)
      generate_sbom "$2" "$3"
      ;;
    check)
      check_deployment_image "$2" "$3"
      ;;
    *)
      echo "Usage: $0 {scan|sign|verify|sbom|check} <image> [extra-arg]"
      echo ""
      echo "Examples:"
      echo "  $0 scan myapp:latest"
      echo "  $0 sign myapp:latest"
      echo "  $0 verify myapp:latest cosign.pub"
      echo "  $0 sbom myapp:latest sbom.json"
      echo "  $0 check myapp:latest cosign.pub"
      ;;
  esac
else
  echo "Usage: $0 {scan|sign|verify|sbom|check} <image> [extra-arg]"
fi
