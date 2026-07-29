# 🌐 Routing Hardcoded Localhost WebSockets via Cloudflare Zero Trust Network

This guide explains how to securely route traffic from a remote web browser to a local BulkSource Connector application that is hardcoded to `ws://localhost:5002`. It uses an application-layer proxy to preserve WebSocket upgrade headers over a secure Cloudflare WARP private network tunnel.

---

## 🖥️ 1. Local Machine Setup (Host Machine)

### 🌐 Cloudflare Tunnel Configuration

1. Open the Cloudflare Zero Trust dashboard and navigate to **Networks** > **Tunnels**.
2. Select your active tunnel, click **Configure**, and open the **Public Hostname** tab.
3. Add a new public hostname entry:
   - **Public Hostname:** `croffordscale-bulksource.karstss.com`
   - **Service Type:** `HTTP`
   - **URL:** `localhost:5002`

### 🔐 Zero Trust Access Policy

1. In the Zero Trust dashboard, go to **Access** > **Applications**.
2. Add or configure the application policy for `croffordscale-bulksource.karstss.com`.
3. Ensure an access rule is created and assigned, such as `Allow-Azure-CloudflareAdmins-Group`, to authorize access.

### 🔁 Local IP Binding Bridge (Netsh)

Because the connector app binds to the loopback interface at `127.0.0.1`, it will reject traffic from outside the local machine. Run the following command in PowerShell as Administrator to bridge incoming WARP traffic to the loopback interface:

```powershell
netsh interface portproxy add v4tov4 listenport=5002 listenaddress=192.168.39.15 connectport=5002 connectaddress=127.0.0.1
```

---

## 🧑‍💻 2. Remote Machine Setup (Client Machine)

### 📡 Cloudflare WARP Client

1. Ensure the Cloudflare WARP/One client is running on the remote machine.
2. Authenticate the WARP profile with an identity that falls within the allowed access policy.
3. Verify that your split-tunnel configuration allows traffic to the host IP address `192.168.39.15`.

### 🧱 Nginx Layer 7 Configuration

To prevent standard Layer 4 proxies from stripping out critical WebSocket upgrade headers, deploy Nginx on the remote machine to handle the application-layer handshake.

Save the following content as `nginx.conf` in your local Nginx configuration directory:

```nginx
events {
    worker_connections 1024;
}

http {
    default_type application/octet-stream;
    sendfile on;

    server {
        # Listen strictly on local plain text port 5002
        listen 127.0.0.1:5002;
        server_name localhost;

        location / {
            # Forward cleanly to your host machine over the WARP IP
            proxy_pass http://192.168.39.15:5002;

            # Explicitly force WebSocket header preservation
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "Upgrade";

            # Forward standard host identity
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

            # Keep the socket pipeline alive indefinitely
            proxy_read_timeout 86400s;
            proxy_send_timeout 86400s;
        }
    }
}
```

---

## 🛠️ 3. Configuring Nginx to Run as a Windows Service

To ensure Nginx starts automatically when the remote machine boots, use the NSSM (Non-Sucking Service Manager) wrapper.

### ⬇️ Step 1: Download NSSM

1. Download the latest stable release of NSSM (for example, from `nssm.cc`).
2. Extract the archive and open the `win64` folder.

### ⚙️ Step 2: Install the Service

Open PowerShell as Administrator inside the directory containing `nssm.exe` and run:

```powershell
.\nssm.exe install Nginx
```

### 🧩 Step 3: Configure Service Parameters

A configuration window will appear. Use the following values:

- **Application Path:** `C:\nginx\nginx.exe`
- **Startup directory:** `C:\nginx`
- **Arguments:** leave blank unless you need a custom config path such as `-c C:\nginx\conf\nginx.conf`

Click **Install service**.

### ▶️ Step 4: Start the Service

Run the following command in an Administrator console:

```powershell
Start-Service -Name "Nginx"
```

> Nginx is now permanently bound to `127.0.0.1:5002` on the remote machine and will automatically handle browser traffic on startup.
