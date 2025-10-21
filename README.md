# Sophos Central API – Disable Tamper Protection (macOS)

This script connects to the **Sophos Central API** to identify a Mac endpoint by its **MAC address** and **serial number**, and then **disables Tamper Protection** remotely using the Sophos API.

---

## 🚀 Features

- Automatically detects the **Mac serial number** and **MAC address**
- Authenticates via **OAuth2** using your Sophos API `client_id` and `client_secret`
- Retrieves **tenant information** dynamically
- Searches for the endpoint by MAC address
- Disables **Tamper Protection** for that specific device

---

## 🧩 Requirements

- macOS with `bash`
- `jq` installed (for JSON parsing)
- Valid Sophos Central **API credentials** (`client_id` and `client_secret`)
- API region: `https://api-eu01.central.sophos.com` (adjust if using another region)

---

## ⚙️ Configuration

Edit the top of the script and add your credentials:

```bash
CLIENT_ID="your_client_id"
CLIENT_SECRET="your_client_secret"
```

---

## 📜 Usage

Simply run the script on a Mac enrolled in Sophos Central:

```bash
sudo bash sophos_disable_tamper.sh
```

The script will:
1. Automatically detect your Mac's serial number and MAC address
2. Authenticate to Sophos Central
3. Find the corresponding endpoint
4. Disable Tamper Protection remotely

---

## 🧠 Example Output

```bash
🔍 Detected Serial Number: J32MV7C32C
🔍 Detected MAC Address: 60:3E:5F:5C:4A:86
🔐 Getting Sophos API token...
✅ Token retrieved.
🌍 Getting tenant info...
✅ Tenant ID: fef4a23b-27f2-453b-b185-012432ddac9e
✅ Region: https://api-eu01.central.sophos.com
🔎 Searching for endpoint with MAC address: 60:3E:5F:5C:4A:86
✅ Endpoint ID found: e57d05eb-e0af-464e-a476-daaac4f4d87a
🛡️ Disabling Tamper Protection for endpoint ID: e57d05eb-e0af-464e-a476-daaac4f4d87a
✅ Tamper Protection successfully disabled.
```

---

## ⚠️ Notes

- The API key must have **Endpoint Management** and **Tamper Protection Control** permissions.
- It can take a few minutes for the action to be reflected in the Sophos Central dashboard.
- All actions are logged in Sophos Central audit logs.

---

## 📄 License

This project is licensed under the **MIT License**.  
You are free to use, modify, and distribute this script with attribution.

---

## 👨‍💻 Author

**Gaëtan Barras**  
IT Operations Manager  
[GitHub Repository](https://github.com/) (add your link here)
