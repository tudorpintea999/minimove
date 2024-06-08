#!/usr/bin/env bash

set -eo pipefail

# Function to extract version from go.mod
extract_version() {
  grep "$1 v" ./go.mod | sed -n -e "s/^.* //p"
}

# URLs and corresponding paths
declare -A REPOS
REPOS=(
  ["github.com/cosmos/cosmos-sdk"]="COSMOS_SDK_VERSION"
  ["github.com/cosmos/ibc-go"]="IBC_VERSION"
  ["github.com/initia-labs/initia"]="INITIA_VERSION"
  ["github.com/initia-labs/OPinit"]="OPINIT_VERSION"
  ["github.com/initia-labs/kvindexer"]="INDEXER_VERSION"
  ["github.com/skip-mev/slinky"]="SLINKY_VERSION"
)

# Clone repositories and extract versions
mkdir -p ./third_party
cd third_party

for URL in "${!REPOS[@]}"; do
  VERSION_VAR="${REPOS[$URL]}"
  VERSION=$(extract_version "$URL")

  if [[ -z "$VERSION" ]]; then
    echo "Error: Version not found for $URL"
    exit 1
  fi

  eval $VERSION_VAR=$VERSION
  git clone -b ${!VERSION_VAR} https://$URL || { echo "Failed to clone $URL"; exit 1; }
done

cd ..

# Start generating Swagger files
mkdir -p ./tmp-swagger-gen
cd proto

proto_dirs=$(find ../third_party/*/proto -name '*.proto' -print0 | xargs -0 -n1 dirname | sort | uniq)
for dir in $proto_dirs; do
  # Generate Swagger files (filter query and service files)
  query_file=$(find "${dir}" -maxdepth 1 \( -name 'query.proto' -o -name 'service.proto' \))
  if [[ -n "$query_file" ]]; then
    buf generate --template buf.gen.swagger.yaml "$query_file"
  fi
done

cd ..

# Combine Swagger files
swagger-combine ./client/docs/config.json -o ./client/docs/swagger-ui/swagger.yaml -f yaml --continueOnConflictingPaths true --includeDefinitions true

# Clean up generated and third-party files
rm -rf ./tmp-swagger-gen ./third_party
