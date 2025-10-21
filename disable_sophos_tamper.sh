#!/bin/bash
# ===============================================
# Sophos Central API — Find endpointId by serial
# ===============================================
# Requirements:
#   - jq installed
#   - valid client_id / client_secret
#   - region = https://api-eu01.central.sophos.com
# ===============================================

# === Configuration ===
# variables à remplir
#CLIENT_ID="your_client_id"
#CLIENT_SECRET="your_client_secret"

# === Auto-detect Mac serial and MAC address ===
SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')
INTERFACE=$(networksetup -listallhardwareports | awk '/Device/ {print $2}' | head -n 1)
MAC_ADDRESS=$(networksetup -getmacaddress "$INTERFACE" | awk '{print $3}')

echo "🔍 Detected Serial Number: $SERIAL"
echo "🔍 Detected MAC Address: $MAC_ADDRESS"


if [[ -z "$SERIAL" ]]; then
  echo "Usage: $0 <Mac_Serial_Number>"
  exit 1
fi

echo "🔐 Getting Sophos API token..."
TOKEN=$(curl -s -X POST "https://id.sophos.com/api/v2/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${CLIENT_ID}&client_secret=${CLIENT_SECRET}&scope=token" \
  | jq -r '.access_token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "❌ Failed to obtain Sophos token."
  exit 1
fi
echo "✅ Token retrieved."

# === Get Tenant & Region Info ===
echo "🌍 Getting tenant info..."
WHOAMI_JSON=$(curl -s -X GET "https://api.central.sophos.com/whoami/v1" \
  -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/json")

TENANT_ID=$(echo "$WHOAMI_JSON" | jq -r '.id')
DATA_REGION=$(echo "$WHOAMI_JSON" | jq -r '.apiHosts.dataRegion')

if [[ -z "$TENANT_ID" || -z "$DATA_REGION" || "$TENANT_ID" == "null" ]]; then
  echo "❌ Failed to retrieve tenant information."
  echo "$WHOAMI_JSON"
  exit 1
fi
echo "✅ Tenant ID: $TENANT_ID"
echo "✅ Region: $DATA_REGION"

# === Query and filter endpoint by MAC address ===

if [[ -z "$MAC_ADDRESS" ]]; then
  echo "Usage: $0 <MAC_ADDRESS>"
  exit 1
fi

echo "🔎 Searching for endpoint with MAC address: $MAC_ADDRESS"

# Récupère la liste des endpoints depuis Sophos Central
ENDPOINT_JSON=$(curl -s -X GET "${DATA_REGION}/endpoint/v1/endpoints" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-Tenant-ID: ${TENANT_ID}" \
  -H "Accept: application/json")

# Vérifie les erreurs
if [[ -z "$ENDPOINT_JSON" || "$ENDPOINT_JSON" == *"error"* ]]; then
  echo "❌ Failed to fetch endpoints or API returned an error."
  echo "$ENDPOINT_JSON"
  exit 1
fi

# Filtre l'endpoint dont la MAC correspond
ENDPOINT_ID=$(echo "$ENDPOINT_JSON" | jq -r --arg MAC "$MAC_ADDRESS" \
'.items[] | select(.macAddresses[] | ascii_upcase == ($MAC | ascii_upcase)) | .id')

if [[ -z "$ENDPOINT_ID" ]]; then
  echo "⚠️ No endpoint found for MAC address $MAC_ADDRESS."
else
  echo "✅ Endpoint ID found: $ENDPOINT_ID"
fi

# === Disable Tamper Protection for the endpoint ===
if [[ -z "$ENDPOINT_ID" || "$ENDPOINT_ID" == "null" ]]; then
  echo "❌ No valid endpoint ID found. Cannot disable Tamper Protection."
  exit 1
fi

echo "🛡️ Disabling Tamper Protection for endpoint ID: $ENDPOINT_ID"

DISABLE_TAMPER=$(curl -s -X POST "${DATA_REGION}/endpoint/v1/endpoints/${ENDPOINT_ID}/tamper-protection" \
-H "Authorization: Bearer ${TOKEN}" \
-H "X-Tenant-ID: ${TENANT_ID}" \
-H "Content-Type: application/json" \
-d '{"enabled": false}')

# Check result
if [[ -z "$DISABLE_TAMPER" || "$DISABLE_TAMPER" == *"error"* ]]; then
  echo "❌ Failed to disable Tamper Protection."
  echo "$DISABLE_TAMPER"
  exit 1
fi

echo "✅ Tamper Protection successfully disabled."
echo "$DISABLE_TAMPER" | jq .
