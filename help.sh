#!/bin/bash

# Script to generate Hyperledger Fabric external builder scripts
# This script creates the necessary directory structure and script files
# under ~/fabric-procurement/chaincode-external

set -euo pipefail # Exit on error, undefined variable, or pipe failure

# Define the base directory relative to the script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BASE_DIR="$SCRIPT_DIR/chaincode-external"

echo "Creating external builder scripts in: $TARGET_BASE_DIR"

# Create the target directory and bin subdirectory
mkdir -p "$TARGET_BASE_DIR/bin"

# --- Create bin/detect ---
DETECT_FILE="$TARGET_BASE_DIR/bin/detect"
cat << 'EOF' > "$DETECT_FILE"
#!/bin/bash
set -euo pipefail
METADIR=$2
# Check if the "type" field is set to "external" in the metadata.json file
if [ "$(jq -r .type "$METADIR/metadata.json")" == "external" ]; then
    exit 0
fi
exit 1
EOF

# --- Create bin/build ---
BUILD_FILE="$TARGET_BASE_DIR/bin/build"
cat << 'EOF' > "$BUILD_FILE"
#!/bin/bash
set -euo pipefail
SOURCE=$1
OUTPUT=$3
# External chaincodes expect connection.json file in the chaincode package
if [ ! -f "$SOURCE/connection.json" ]; then
    >&2 echo "$SOURCE/connection.json not found"
    exit 1
fi
# Simply copy the endpoint information to specified output location
cp $SOURCE/connection.json $OUTPUT/connection.json
if [ -d "$SOURCE/metadata" ]; then
    cp -a $SOURCE/metadata $OUTPUT/metadata
fi
exit 0
EOF

# --- Create bin/release ---
RELEASE_FILE="$TARGET_BASE_DIR/bin/release"
cat << 'EOF' > "$RELEASE_FILE"
#!/bin/bash
set -euo pipefail
BLD="$1"
RELEASE="$2"
if [ -d "$BLD/metadata" ]; then
   cp -a "$BLD/metadata/"* "$RELEASE/"
fi
# External chaincodes expect artifacts to be placed under "$RELEASE"/chaincode/server
if [ -f $BLD/connection.json ]; then
   mkdir -p "$RELEASE"/chaincode/server
   cp $BLD/connection.json "$RELEASE"/chaincode/server
   # If tls_required is true, copy TLS files (using above example, the fully qualified path for these fils would be "$RELEASE"/chaincode/server/tls)
   exit 0
fi
exit 1
EOF

# --- Make the scripts executable ---
chmod +x "$DETECT_FILE" "$BUILD_FILE" "$RELEASE_FILE"

