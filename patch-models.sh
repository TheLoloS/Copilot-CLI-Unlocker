#!/bin/bash

# Copilot CLI Unlocker (Dual Array Version - FIXED for MinGW)
# Adds additional models to both of the GitHub Copilot CLI's model arrays:
# 1. The simple name array (e.g., Yv=["model1", "model2"])
# 2. The model object array (e.g., Dwe=[{model:"model1",label:"Label1"},...])
#
# Usage:
#   ./patch-models.sh [--file /path/to/index.js] [--dry-run] [--models model1,model2]

set -euo pipefail

# --- Configuration ---
COPILOT_PATH=""
SEARCH_PATHS=(
    "$HOME/node_modules/@github/copilot/index.js"
    "$(npm root -g 2>/dev/null)/@github/copilot/index.js"
    "/usr/local/lib/node_modules/@github/copilot/index.js"
    "/opt/homebrew/lib/node_modules/@github/copilot/index.js"
)

# Function to detect if running under a Windows-like environment (WSL, Git Bash, etc.)
is_windows_like() {
    # Check for WSL via specific environment variables or kernel name
    if grep -qE "(Microsoft|WSL)" /proc/version &>/dev/null; then
        return 0 # Success (it's WSL)
    fi
    # Check for Git Bash, MinGW, Cygwin via OSTYPE
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == mingw* ]]; then
        return 0 # Success (it's Git Bash/etc.)
    fi
    return 1 # Failure (it's likely a native Linux/macOS)
}

# Add Windows-style paths if running in a Windows-like environment
if is_windows_like; then
    # In WSL, Windows drives are mounted under /mnt/
    # In Git Bash, they are mounted directly, e.g., /c/
    # We need to find the correct root for the C drive.
    WIN_C_DRIVE=""
    if [[ -d "/mnt/c" ]]; then
        WIN_C_DRIVE="/mnt/c" # WSL style
    elif [[ -d "/c" ]]; then
        WIN_C_DRIVE="/c"     # Git Bash style
    fi

    # Proceed only if we found the C drive mount point
    if [[ -n "$WIN_C_DRIVE" ]]; then
        # Dynamically get APPDATA path. In WSL, env vars from Windows are not always present.
        # We find it relative to the Windows user profile.
        WIN_USER_PROFILE=$(wslpath "$(wslvar USERPROFILE 2>/dev/null)" 2>/dev/null || echo "$WIN_C_DRIVE/Users/$(whoami)")
        WIN_APPDATA="$WIN_USER_PROFILE/AppData/Roaming"
        
        SEARCH_PATHS+=(
            "$WIN_APPDATA/npm/node_modules/@github/copilot/index.js"
            "$WIN_C_DRIVE/Program Files/nodejs/node_modules/@github/copilot/index.js"
        )
    fi
fi

for path in "${SEARCH_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        COPILOT_PATH="$path"
        break
    fi
done

TARGET_FILE="${COPILOT_PATH}"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false
# Default models to add; you can change or override with the --models flag
MODELS_TO_ADD=("gpt-4.1" "gpt-4o" "gpt-5-mini" "grok-code-fast-1" "gemini-2.5-pro") 

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --file) TARGET_FILE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --models) IFS=',' read -ra MODELS_TO_ADD <<< "$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "  --file PATH       Path to index.js (default: auto-detected)"
            echo "  --dry-run         Preview changes without modifying files"
            echo "  --models M1,M2    Comma-separated list of models to add"
            exit 0
            ;;
        *) echo -e "${RED}❌ Unknown option: $1${NC}"; exit 1 ;;
    esac
done

# --- Helper function to generate labels ---
generate_label() {
    local model_name=$1
    echo "$model_name" | sed -e 's/-/ /g' -e "s/\b\(.\)/\u\1/g" -e 's/Gpt/GPT/g'
}
 
# --- Main logic ---
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Copilot CLI Unlocker (Dual Array Version)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [[ ! -f "$TARGET_FILE" ]]; then
    echo -e "${RED}❌ Error: File not found: $TARGET_FILE${NC}"
    echo "Could not auto-detect Copilot installation. Use --file to specify the path."
    exit 1
fi
echo -e "${GREEN}✓${NC} Target file: $TARGET_FILE"

# --- Step 1: Process first array (simple names) ---
echo ""
echo -e "${YELLOW}Step 1: Processing names array (e.g., Yv=[...])...${NC}"

NAMES_ARRAY_PATTERN=$(grep -o '[A-Za-z_$][A-Za-z0-9_$]*=\["claude-sonnet-[^]]*\]' "$TARGET_FILE" | head -n 1 || true)
if [[ -z "$NAMES_ARRAY_PATTERN" ]]; then
    echo -e "${RED}❌ Error: Could not find the simple names array.${NC}"
    exit 1
fi

NAMES_VAR_NAME=$(echo "$NAMES_ARRAY_PATTERN" | cut -d'=' -f1)
CURRENT_NAMES_ARRAY=$(echo "$NAMES_ARRAY_PATTERN" | cut -d'=' -f2)

echo -e "${GREEN}✓${NC} Found variable: ${BLUE}$NAMES_VAR_NAME${NC}"

# Use perl for proper extraction to avoid malformed arrays
CURRENT_MODELS_STR=$(echo "$CURRENT_NAMES_ARRAY" | perl -pe 's/^\[//; s/\]$//; s/"//g')

# Split by comma into bash array
IFS=',' read -ra CURRENT_MODELS <<< "$CURRENT_MODELS_STR"

# Create new array explicitly
NEW_NAMES_MODELS=("${CURRENT_MODELS[@]}")
MODELS_ADDED=()
for model in "${MODELS_TO_ADD[@]}"; do
    if [[ " ${CURRENT_MODELS[*]} " != *" $model "* ]]; then
        NEW_NAMES_MODELS+=("$model")
        MODELS_ADDED+=("$model")
        echo -e "${GREEN}+${NC}  Adding model: $model"
    else
        echo -e "${YELLOW}⚠${NC}  Model '$model' already exists in names array, skipping."
    fi
done

if [[ ${#MODELS_ADDED[@]} -eq 0 ]]; then
    echo -e "${YELLOW}✔ No new models to add. File seems up to date.${NC}"
    exit 0
fi

NEW_NAMES_ARRAY_STR="["
for i in "${!NEW_NAMES_MODELS[@]}"; do
    [[ $i -gt 0 ]] && NEW_NAMES_ARRAY_STR+=","
    NEW_NAMES_ARRAY_STR+="\"${NEW_NAMES_MODELS[$i]}\""
done
NEW_NAMES_ARRAY_STR+="]"
SEARCH_PATTERN_1="${NAMES_VAR_NAME}=${CURRENT_NAMES_ARRAY}"
REPLACEMENT_1="${NAMES_VAR_NAME}=${NEW_NAMES_ARRAY_STR}"


# --- Step 2: Process second array (objects with labels) ---
echo ""
echo -e "${YELLOW}Step 2: Processing objects array (e.g., Dwe=[{...}])...${NC}"

# ==============================================================================
#   FIXED LINE BELOW - removed the escaped backslash before '{'
# ==============================================================================
OBJECTS_ARRAY_PATTERN=$(grep -o '[A-Za-z_$][A-Za-z0-9_$]*=\[{model:"claude-sonnet-[^]]*\]' "$TARGET_FILE" | head -n 1 || true)

if [[ -z "$OBJECTS_ARRAY_PATTERN" ]]; then
    echo -e "${RED}❌ Error: Could not find the model objects array.${NC}"
    exit 1
fi

OBJECTS_VAR_NAME=$(echo "$OBJECTS_ARRAY_PATTERN" | cut -d'=' -f1)
CURRENT_OBJECTS_ARRAY=$(echo "$OBJECTS_ARRAY_PATTERN" | cut -d'=' -f2)

echo -e "${GREEN}✓${NC} Found variable: ${BLUE}$OBJECTS_VAR_NAME${NC}"

NEW_OBJECTS_ARRAY_STR="${CURRENT_OBJECTS_ARRAY%?}"
for model in "${MODELS_ADDED[@]}"; do
    LABEL=$(generate_label "$model")
    NEW_OBJECTS_ARRAY_STR+=",{model:\"$model\",label:\"$LABEL\"}"
    echo -e "${GREEN}+${NC}  Adding object: {model:\"$model\", label:\"$LABEL\"}"
done
NEW_OBJECTS_ARRAY_STR+="]"

SEARCH_PATTERN_2="${OBJECTS_VAR_NAME}=${CURRENT_OBJECTS_ARRAY}"
REPLACEMENT_2="${OBJECTS_VAR_NAME}=${NEW_OBJECTS_ARRAY_STR}"


# --- Step 3: Preview or apply changes ---
echo ""
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  DRY RUN MODE - No changes will be made${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Would perform 2 replacements:"
    echo -e "  ${RED}1. FROM:${NC} $SEARCH_PATTERN_1"
    echo -e "     ${GREEN}TO:${NC}   $REPLACEMENT_1"
    echo ""
    echo -e "  ${RED}2. FROM:${NC} $SEARCH_PATTERN_2"
    echo -e "     ${GREEN}TO:${NC}   $REPLACEMENT_2"
    echo ""
    echo -e "${BLUE}Verification: Checking array construction...${NC}"
    echo -e "First element of new array: ${GREEN}${NEW_NAMES_MODELS[0]}${NC}"
    last_idx=$((${#NEW_NAMES_MODELS[@]} - 1))
    echo -e "Last element of new array: ${GREEN}${NEW_NAMES_MODELS[$last_idx]}${NC}"
    echo -e "Total elements: ${GREEN}${#NEW_NAMES_MODELS[@]}${NC}"
    exit 0
fi

echo -e "${YELLOW}Step 3: Applying patch...${NC}"

BACKUP_FILE="${TARGET_FILE}${BACKUP_SUFFIX}"
echo -e "${BLUE}📦${NC} Creating backup: $BACKUP_FILE"
cp "$TARGET_FILE" "$BACKUP_FILE"

export SEARCH_PATTERN_1 REPLACEMENT_1
perl -i -pe 'BEGIN{undef $/;} s/\Q$ENV{SEARCH_PATTERN_1}\E/$ENV{REPLACEMENT_1}/g' "$TARGET_FILE"

export SEARCH_PATTERN_2 REPLACEMENT_2
perl -i -pe 'BEGIN{undef $/;} s/\Q$ENV{SEARCH_PATTERN_2}\E/$ENV{REPLACEMENT_2}/g' "$TARGET_FILE"

# --- Step 4: Verification ---
if grep -qF "$REPLACEMENT_1" "$TARGET_FILE" && grep -qF "$REPLACEMENT_2" "$TARGET_FILE"; then
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✅ Successfully patched both arrays!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}📋${NC} Backup saved to: $BACKUP_FILE"
    echo ""
    echo "Models now available:"
    for model in "${MODELS_ADDED[@]}"; do
        LABEL=$(generate_label "$model")
        echo -e "  - $model (${GREEN}Label: '$LABEL'${NC})"
    done
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Test the copilot binary before using it!${NC}"
    echo -e "   Run: ${BLUE}copilot --version${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  🎉  You can select models by /model command or: ${NC} "
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Edit your Copilot config (${BLUE}$HOME/.copilot/config.json${NC}) and set:"
    echo -e "  ${GREEN}\"model\": \"${MODELS_ADDED[0]}\"${NC} (or another new model)"

else
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ❌ Error: Patching failed! Verification check failed.${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Restoring from backup..."
    mv "$BACKUP_FILE" "$TARGET_FILE"
    exit 1
fi