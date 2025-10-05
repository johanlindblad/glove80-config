#!/usr/bin/env bash
set -euo pipefail

# Draw keymaps script. Prefer running under mise: `mise run draw`.
# If mise is available but not active, we attempt to run the script via mise exec.

out="./img"
keymap_dir="./config"
cfg="$keymap_dir/keymap_drawer.yaml"

# If mise exists and is not active in this shell, re-run under mise so tools from mise.toml are available.
if command -v mise >/dev/null 2>&1 && [ -z "${MISE_ACTIVE:-}" ]; then
  echo "Re-running under mise to provide an isolated environment..."
  exec mise run draw
fi

mkdir -p "$out"

if ! command -v keymap >/dev/null 2>&1; then
  echo "error: 'keymap' CLI not found in PATH. Install it and re-run." >&2
  exit 1
fi

shopt -s nullglob
files=("$keymap_dir"/*.keymap)
if [ ${#files[@]} -eq 0 ]; then
  echo "No .keymap files found in $keymap_dir"
  exit 0
fi

for file in "${files[@]}"; do
  name=$(basename "$file")
  name=${name%.keymap}
  config="$out/$name.yaml"
  echo "Found $name keymap"

  echo "- Removing old images"
  rm -f "$out/$name.yaml" "$out/$name".svg "$out/$name"_*.svg || true

  echo "- Parsing keymap"
  keymap --config "$cfg" parse --zmk-keymap "$file" > "$config"

  echo "- Drawing all layers"
  keymap --config "$cfg" draw "$config" > "$out/$name".svg

  echo "- Enumerating layers"
  layers=""
  if command -v yq >/dev/null 2>&1; then
    # Try mikefarah yq v4 first
    if yq --version 2>&1 | grep -q "version 4"; then
      layers=$(yq e '.layers | keys | .[]' "$config" || true)
    else
      # fallback for other yq implementations
      layers=$(yq '.layers | keys | .[]' "$config" 2>/dev/null || true)
    fi
  elif command -v python3 >/dev/null 2>&1; then
    # Use Python + PyYAML to extract layer names (if PyYAML is installed)
    if python3 -c "import yaml" >/dev/null 2>&1; then
      layers=$(python3 -c 'import sys,yaml;d=yaml.safe_load(open(sys.argv[1]));print("\n".join(d.get("layers",{}).keys()))' "$config")
    else
      # Try the project venv if it exists
      if [ -f ".venv/bin/python" ]; then
        if .venv/bin/python -c "import yaml" >/dev/null 2>&1; then
          layers=$( .venv/bin/python -c 'import sys,yaml;d=yaml.safe_load(open(sys.argv[1]));print("\n".join(d.get("layers",{}).keys()))' "$config" )
        else
          echo "warning: PyYAML not found in system python or .venv; run 'mise run setup' or 'python -m pip install pyyaml'" >&2
        fi
      else
        echo "warning: python3 is available but the 'yaml' module (PyYAML) is missing; install with 'pip install pyyaml' or run 'mise run setup' to create .venv" >&2
      fi
    fi
  else
    echo "warning: neither 'yq' nor 'python3' is available, skipping per-layer images" >&2
  fi

  if [ -n "${layers:-}" ]; then
    for layer in $layers; do
      # Trim possible quotes and whitespace
      layer_trimmed=$(echo "$layer" | sed -e 's/^\s*"\?//' -e 's/"\?\s*$//')
      echo "- Drawing layer: $layer_trimmed"
      keymap --config "$cfg" draw "$config" --select-layers "$layer_trimmed" > "$out/$name"_"$layer_trimmed".svg
    done
  fi

done

echo "Done. Generated SVGs are in: $out"