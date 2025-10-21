#!/bin/bash
# ===============================================
# sophos_api_disable_tamper.sh
# - Auth to Sophos Central
# - Find endpoint by local MAC
# - Disable Tamper Protection via API
# - If disabled, run local Sophos uninstaller
# Requirements:
#   - jq installed
#   - valid CLIENT_ID / CLIENT_SECRET
#   - network access to Sophos Central
# ===============================================

# === Configuration (fill these) ===
CLIENT_ID=""        # <-- fill
CLIENT_SECRET=""    # <-- fill

# === Helper logging ===
log() { echo "$(date -u +"%Y-%m-%d %T %Z") - $*"; }

# === Auto-detect Mac serial and MAC address ===
SERIAL=$(system_profiler SPHardwareDataType 2>/dev/null | awk '/Serial Number/{print $4}')
INTERFACE=$(networksetup -listallhardwareports 2>/dev/null | awk '/Device/ {print $2}' | head -n 1)
MAC_ADDRESS=$(networksetup -getmacaddress "$INTERFACE" 2>/dev/null | awk '{print $3}')

log "Detected Serial: ${SERIAL:-UNKNOWN}"
log "Detected MAC: ${MAC_ADDRESS:-UNKNOWN}"

# Basic checks
if [[ -z "$CLIENT_ID" || -z "$CLIENT_SECRET" ]]; then
  log "ERROR: CLIENT_ID and CLIENT_SECRET must be set in the script."
  exit 1
fi

if [[ -z "$MAC_ADDRESS" ]]; then
  log "ERROR: Could not detect MAC address. Aborting."
  exit 1
fi

# === 1) Get OAuth2 token from Sophos ID ===
log "Requesting Sophos API token..."
TOKEN=$(curl -s -X POST "https://id.sophos.com/api/v2/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&scope=token" \
  | jq -r '.access_token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  log "ERROR: Unable to obtain Sophos token."
  exit 1
fi
log "Token retrieved."

# === 2) WhoAmI to get tenant & region ===
WHOAMI_JSON=$(curl -s -X GET "https://api.central.sophos.com/whoami/v1" \
  -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json")

TENANT_ID=$(echo "$WHOAMI_JSON" | jq -r '.id')
DATA_REGION=$(echo "$WHOAMI_JSON" | jq -r '.apiHosts.dataRegion')

if [[ -z "$TENANT_ID" || -z "$DATA_REGION" || "$TENANT_ID" == "null" ]]; then
  log "ERROR: Failed to retrieve tenant info. Response:"
  echo "$WHOAMI_JSON"
  exit 1
fi
log "Tenant ID: $TENANT_ID"
log "Data region: $DATA_REGION"

# === 3) Get endpoints list (first page) and search by MAC ===
log "Fetching endpoints list..."
ENDPOINT_JSON=$(curl -s -X GET "${DATA_REGION}/endpoint/v1/endpoints" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Tenant-ID: ${TENANT_ID}" \
  -H "Accept: application/json")

if [[ -z "$ENDPOINT_JSON" || "$ENDPOINT_JSON" == *"error"* ]]; then
  log "ERROR: Failed to fetch endpoints or API returned error."
  echo "$ENDPOINT_JSON"
  exit 1
fi

# find endpoint ID by matching any macAddresses entry (case-insensitive)
ENDPOINT_ID=$(echo "$ENDPOINT_JSON" | jq -r --arg MAC "$MAC_ADDRESS" \
  '.items[] | select(.macAddresses[]? | ascii_downcase == ($MAC | ascii_downcase)) | .id' | head -n 1)

if [[ -z "$ENDPOINT_ID" ]]; then
  log "WARNING: No endpoint found for MAC $MAC_ADDRESS. Exiting."
  exit 2
fi
log "Endpoint ID found: $ENDPOINT_ID"

# === 4) Fetch detailed info (optional) ===
DETAILS_JSON=$(curl -s -X GET "${DATA_REGION}/endpoint/v1/endpoints/${ENDPOINT_ID}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Tenant-ID: ${TENANT_ID}" \
  -H "Accept: application/json")

log "Endpoint details (summary):"
echo "$DETAILS_JSON" | jq -r '{id: .id, hostname: .hostname, os: .os.name, tamperProtectionEnabled: .tamperProtectionEnabled, lastSeenAt: .lastSeenAt}'

# === 5) Disable Tamper Protection via API ===
log "Disabling Tamper Protection for endpoint ${ENDPOINT_ID}..."
DISABLE_TAMPER=$(curl -s -X POST "${DATA_REGION}/endpoint/v1/endpoints/${ENDPOINT_ID}/tamper-protection" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Tenant-ID: ${TENANT_ID}" \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}')

if [[ -z "$DISABLE_TAMPER" || "$DISABLE_TAMPER" == *"error"* ]]; then
  log "ERROR: Failed to disable Tamper Protection. Response:"
  echo "$DISABLE_TAMPER"
  exit 1
fi

# parse result to confirm disabled
NEW_ENABLED=$(echo "$DISABLE_TAMPER" | jq -r '.enabled // empty')

if [[ "$NEW_ENABLED" == "false" ]]; then
  log "Tamper Protection disabled successfully."
else
  log "ERROR: API returned unexpected tamper-protection state:"
  echo "$DISABLE_TAMPER" | jq .
  exit 1
fi

# === 6) If disabled -> attempt local uninstall of Sophos Endpoint ===
REMOVE_APP="/Applications/Remove Sophos Endpoint.app"
UNINSTALL_TOOL="$REMOVE_APP/Contents/MacOS/tools/InstallationDeployer"

if [[ -d "$REMOVE_APP" && -x "$UNINSTALL_TOOL" ]]; then
  log "Found Remove Sophos Endpoint app. Running uninstaller..."
  # run uninstall as root (Jamf runs as root). No tamper password required because tamper was disabled.
  "$UNINSTALL_TOOL" --force_remove
  UNINST_EXIT=$?
  log "Uninstall tool exit code: $UNINST_EXIT"
else
  log "Remove Sophos Endpoint app or tool not found at $REMOVE_APP. Skipping local uninstall."
  UNINST_EXIT=127
fi

# wait a little and check for common leftovers/processes
sleep 3

# basic verification: check processes and common folders
if pgrep -f "Sophos" >/dev/null 2>&1; then
  log "WARNING: Sophos processes still running after uninstall attempt."
  UNINST_SUCCESS=0
else
  # check common Sophos directories
  if [[ -d "/Library/Sophos Anti-Virus" || -d "/Library/Application Support/Sophos" || -d "/Library/Sophos" ]]; then
    log "NOTE: Some Sophos directories still exist under /Library (possible partial uninstall)."
    UNINST_SUCCESS=0
  else
    log "Sophos appears removed (no processes, no standard dirs)."
    UNINST_SUCCESS=1
  fi
fi

if [[ "$UNINST_SUCCESS" -eq 1 ]]; then
  log "Uninstall completed successfully."
  exit 0
else
  log "Uninstall may be incomplete. Exit code: $UNINST_EXIT"
  # Suggest next steps
  log "Suggested actions:"
  log "- Ensure the Remove Sophos Endpoint app is present on the machine"
  log "- If Tamper was disabled remotely, re-run the local uninstaller with the tamper password if required"
  log "- Alternatively use Sophos Central to trigger a managed uninstall"
  exit 3
fi
