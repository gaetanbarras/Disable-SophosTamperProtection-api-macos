# Sophos Central API – Disable Tamper Protection (macOS)

This repository contains scripts to interact with the **Sophos Central API** for managing macOS endpoints, specifically to **disable Tamper Protection** and optionally **uninstall Sophos Endpoint Protection** automatically.

---

## 🚀 Overview

| Script | Description |
|--------|--------------|
| `disable_sophos_tamper.sh` | Authenticates to Sophos Central, detects the local Mac, finds the endpoint by MAC address, and disables Tamper Protection remotely. |
| `disable_sophos_tamper_and_uninstall.sh` | Extends the above script — after disabling Tamper Protection successfully, it runs the local **Sophos Endpoint uninstaller** to fully remove the agent. |

---

## 🧩 Features

- 🔒 **Disables Sophos Tamper Protection remotely** via API  
- 🖥️ **Automatically detects the Mac serial number and MAC address**
- 🌍 **Authenticates** with your Sophos API credentials (`client_id`, `client_secret`)
- 🧠 **Retrieves tenant information** and regional API host dynamically
- 🧹 **Optionally uninstalls** Sophos Endpoint locally when protection is disabled
- 📜 **Clean logs and checks** for partial uninstall or leftover processes

---

## ⚙️ Requirements

- macOS with **bash**
- `jq` installed (`brew install jq`)
- Valid Sophos Central API credentials:
  - `client_id`
  - `client_secret`
- API region: `https://api-eu01.central.sophos.com` (adjust for your region if needed)
- The Sophos Endpoint uninstaller must exist locally at:
  ```
  /Applications/Remove Sophos Endpoint.app/Contents/MacOS/tools/InstallationDeployer
  ```

---

## 🧠 How It Works

Both scripts perform the following main steps:

1. **Detect the local Mac info**
   ```bash
   SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')
   MAC_ADDRESS=$(networksetup -getmacaddress en0 | awk '{print $3}')
   ```

2. **Obtain a Sophos OAuth2 Token**
   via `https://id.sophos.com/api/v2/oauth2/token`

3. **Retrieve Tenant Information**
   using `https://api.central.sophos.com/whoami/v1`

4. **Find the endpoint** matching the local MAC address:
   - Endpoint list fetched via `/endpoint/v1/endpoints`
   - Matched using `.macAddresses[]`

5. **Disable Tamper Protection**
   ```bash
   POST /endpoint/v1/endpoints/{endpointId}/tamper-protection
   Body: {"enabled": false}
   ```

6. **(Optional)** If Tamper Protection is disabled:
   - The script `disable_sophos_tamper_and_uninstall.sh` runs:
     ```
     /Applications/Remove Sophos Endpoint.app/Contents/MacOS/tools/InstallationDeployer --force_remove
     ```
   - Then checks for active Sophos processes and leftover directories under `/Library`.

---

## 📜 Example Output (anonymized)

```
🔍 Detected Serial Number: XXXXXXXX1234
🔍 Detected MAC Address: XX:XX:XX:XX:XX:XX
🔐 Getting Sophos API token...
✅ Token retrieved.
🌍 Getting tenant info...
✅ Tenant ID: ********-****-****-****-************
✅ Region: https://api-xx01.central.sophos.com
🔎 Searching for endpoint with MAC address: XX:XX:XX:XX:XX:XX
✅ Endpoint ID found: ********-****-****-****-************
🛡️ Disabling Tamper Protection for endpoint ID: ********-****-****-****-************
✅ Tamper Protection successfully disabled.
🧹 Running Sophos Endpoint uninstaller...
✅ Uninstall completed successfully.
```

---

## ⚠️ Important Notes

- The API credentials must have permissions for:
  - **Endpoint Management**
  - **Tamper Protection Control**
- API actions may take a few minutes to propagate.
- All actions are logged in **Sophos Central audit logs**.
- Ensure network access to:
  - `id.sophos.com`
  - `api.central.sophos.com`
  - Your regional API endpoint (e.g. `api-eu01.central.sophos.com`).

---

## 🧰 Scripts Summary

### `disable_sophos_tamper.sh`
- Minimal script to disable Tamper Protection remotely.
- Safe to use in production for unlocking protected endpoints.

### `disable_sophos_tamper_and_uninstall.sh`
- Builds on the previous script.
- If the Tamper Protection API confirms `enabled=false`, runs:
  ```
  /Applications/Remove Sophos Endpoint.app/Contents/MacOS/tools/InstallationDeployer --force_remove
  ```
- Verifies removal by checking for running processes and remaining directories.

---

## 🧾 License

This project is licensed under the **MIT License**.

```
MIT License

Copyright (c) 2025 Gaëtan Barras

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

[...]
```

---

## 👨‍💻 Author

**Gaëtan Barras**  
IT Operations Manager  
[GitHub Repository](https://github.com/) (replace with your repo URL)
