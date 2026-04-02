# WireGuard CX23 Day-1 Runbook

## Scope

- New clean rollout on Hetzner CX23
- Canonical WireGuard subnet: 10.100.0.0/24
- First iteration: WireGuard + SSH only
- No reverse proxy or public app exposure

## Preconditions

- Hetzner CX23 provisioned with Ubuntu 22.04 LTS
- SSH key deployed during provisioning (see Step 0 below)
- You have SSH access as root via key authentication (not password)
- Local WireGuard peer key pair is generated on laptop and stored safely
- Old endpoint credentials are considered compromised and will be rotated

## Address plan

- VPS hub: 10.100.0.1/24
- Laptop peer: 10.100.0.2/32
- Lenovo Tiny peer: 10.100.0.3/32
- Optional mobile/emergency peer: 10.100.0.4/32

Use this as the canonical allocation order for the first rollout. Keep peer IPs stable once assigned.

## Step 0: Prepare SSH key and provision VPS

Before ordering the VPS, generate your SSH keypair on your laptop:

```powershell
# On Windows laptop (PowerShell)
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\id_ed25519_hetzner_admin_laptop_01" -N "" -C "hetzner_cx23_admin_key_$(Get-Date -Format 'yyyy-MM-dd')"
```

Or on Linux/macOS:

```bash
# On Linux/macOS
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_hetzner_admin_laptop_01 -N "" -C "hetzner_cx23_admin_key_$(date +%Y-%m-%d)"
```

View your public key:

```powershell
# Windows
Get-Content "$env:USERPROFILE\.ssh\id_ed25519_hetzner_admin_laptop_01.pub"
```

```bash
# Linux/macOS
cat ~/.ssh/id_ed25519_hetzner_admin_laptop_01.pub
```

When provisioning the VPS in Hetzner Cloud Console:

1. Create SSH key in Hetzner Cloud Console:
   - Go to [https://console.hetzner.cloud/](https://console.hetzner.cloud/) → Project Settings → SSH Keys
   - Click "Add SSH Key"
   - Paste your public key content (the .pub file)
   - Name it: `admin-laptop-01-ed25519` or similar
   
2. Create the CX23 server:
   - Select Ubuntu 22.04 LTS as image
   - In "SSH Keys" section, select or create the key you just added
   - Start the server
   - Note the public IP address

3. Verify SSH access on your laptop:

```powershell
# Windows - test connectivity
$publicIp = "<CX23_PUBLIC_IP>"
ssh -i "$env:USERPROFILE\.ssh\id_ed25519_hetzner_admin_laptop_01" root@$publicIp "hostname; uname -a"
```

```bash
# Linux/macOS
ssh -i ~/.ssh/id_ed25519_hetzner_admin_laptop_01 root@<CX23_PUBLIC_IP> "hostname; uname -a"
```

Expected: successful login without password prompt, output shows hostname and Ubuntu version.

**References:**
- [Hetzner Cloud - SSH Keys documentation](https://docs.hetzner.com/cloud/servers/basics/ssh-keys)
- [Ed25519 key generation best practices](https://wiki.archlinux.org/title/SSH_keys#Generating_an_SSH_key_pair)

## Step 1: Bootstrap VPS user and SSH

Run on VPS as root:

```bash
adduser admin
usermod -aG sudo admin
mkdir -p /home/admin/.ssh
cp /root/.ssh/authorized_keys /home/admin/.ssh/authorized_keys
chown -R admin:admin /home/admin/.ssh
chmod 700 /home/admin/.ssh
chmod 600 /home/admin/.ssh/authorized_keys
```

Harden SSH:

```bash
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh
```

Validation from your laptop:

```powershell
# Windows
ssh -i "$env:USERPROFILE\.ssh\id_ed25519_hetzner_admin_laptop_01" admin@<CX23_PUBLIC_IP>
```

```bash
# Linux/macOS
ssh -i ~/.ssh/id_ed25519_hetzner_admin_laptop_01 admin@<CX23_PUBLIC_IP>
```

Expected: successful login as `admin` user without password prompt.

## Step 2: Firewall baseline

Run on VPS as admin with sudo:

```bash
sudo apt update
sudo apt install -y ufw wireguard wireguard-tools
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw default deny routed
sudo ufw allow 22/tcp comment "SSH"
sudo ufw allow 51820/udp comment "WireGuard"
sudo ufw route allow in on wg0 comment "Allow routed WireGuard traffic"
sudo ufw --force enable
sudo ufw status verbose
```

Expected output should show:
- `Default: deny (incoming), allow (outgoing), deny (routed)`
- Two explicit allow rules: `22/tcp` and `51820/udp`
- One route rule allowing traffic on `wg0` interface

Before moving to the next step, verify SSH service status:

```bash
sudo systemctl status ssh
sudo netstat -ln | grep :22
```

Expected: sshd listening on `:::22` or `0.0.0.0:22` (both IPv4 and IPv6).

## Step 3: Install server key and config

Create server private key on VPS:

```bash
sudo umask 077
sudo wg genkey | sudo tee /etc/wireguard/wg-prod-hub-hetzner-cx23-01.private | sudo wg pubkey | sudo tee /etc/wireguard/wg-prod-hub-hetzner-cx23-01.public
sudo chmod 600 /etc/wireguard/wg-prod-hub-hetzner-cx23-01.private
```

Create server config:

```bash
sudo tee /etc/wireguard/wg0.conf > /dev/null <<'EOF'
[Interface]
Address = 10.100.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>

[Peer]
PublicKey = <LAPTOP_PUBLIC_KEY>
AllowedIPs = 10.100.0.2/32
EOF
```

Replace `<SERVER_PRIVATE_KEY>` with the content of `/etc/wireguard/wg-prod-hub-hetzner-cx23-01.private`.

Start service:

```bash
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
sudo wg show
```

## Step 4: Configure laptop peer

**Prerequisite:** SSH client config must be set up on your laptop first.
See [wireguard-client-laptop-prep.md](../wireguard-client-laptop-prep.md#observation-2-explicit-ssh-client-configuration-was-required) for SSH config setup.

Use template in infra/wireguard/client.conf.example and fill real values.

Client config:

```ini
[Interface]
PrivateKey = <LAPTOP_PRIVATE_KEY>
Address = 10.100.0.2/32

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = <CX23_PUBLIC_IP>:51820
AllowedIPs = 10.100.0.0/24
PersistentKeepalive = 25
```

Import in WireGuard client and activate.

Validation from laptop (using SSH config alias):

```powershell
ping 10.100.0.1
ssh hetzner-wg "hostname; uname -a"
```

If SSH config is not yet set up, use explicit key:

```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519_hetzner_admin_laptop_01" admin@10.100.0.1 "hostname; uname -a"
```

Expected: ping succeeds, SSH login works without password prompt, output shows VPS hostname and Ubuntu version.

Validation on VPS:

```bash
sudo wg show
```

Expected: recent handshake and data transfer counters on laptop peer.

## Step 4b (REQUIRED if using Lenovo Tiny): Enable peer-to-peer routing via hub

**Prerequisite:** Step 4 must be complete and validated. Laptop must already be able to SSH into VPS via tunnel.

If you are adding Lenovo Tiny as a managed peer, peer-to-peer routing is mandatory.
If you plan management-only rollout (laptop to VPS only), skip Step 4b and Step 4c.

Enable IPv4 forwarding on hub:

```bash
sudo sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-wireguard-forwarding.conf
sudo sysctl --system
```

Required peer `AllowedIPs` model for peer-to-peer:
- Hub `wg0.conf`: keep one `/32` per peer in each `[Peer]` block.
- Laptop peer config: route the WireGuard subnet via hub, for example `AllowedIPs = 10.100.0.0/24`.
- Lenovo peer config: route the WireGuard subnet via hub, for example `AllowedIPs = 10.100.0.0/24`.

Why this is required:
- Handshake success alone does not prove peer-to-peer reachability.
- Without forwarding and explicit return-path `AllowedIPs`, traffic can fail silently or report destination unreachable.

## Step 4c: Bootstrap Lenovo Tiny as peer

**Prerequisite:** Step 4b must be complete. IPv4 forwarding must already be enabled on VPS.

Run on Lenovo Tiny to generate keys and config (repo must be cloned):

```bash
WG_ENV=prod WG_ROLE=peer \
  ./scripts/testing/bootstrap_wg_peer.sh \
  home-lenovo-tiny-01 10.100.0.3/32 <CX23_PUBLIC_IP>:51820 <SERVER_PUBLIC_KEY>
```

This generates in `~/wireguard-local/`:
- `wg-prod-peer-home-lenovo-tiny-01.private`
- `wg-prod-peer-home-lenovo-tiny-01.public`
- `wg-prod-peer-home-lenovo-tiny-01.conf`

Install config on Lenovo Tiny:

```bash
sudo apt install -y wireguard wireguard-tools
sudo cp ~/wireguard-local/wg-prod-peer-home-lenovo-tiny-01.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf
```

Add Lenovo as peer on Hetzner hub (run with Lenovo public key in hand):

```bash
LENOVO_PUBKEY=$(cat /path/to/wg-prod-peer-home-lenovo-tiny-01.public)
sudo wg set wg0 peer "$LENOVO_PUBKEY" allowed-ips 10.100.0.3/32
sudo wg-quick save wg0
sudo wg show
```

Start WireGuard on Lenovo Tiny:

```bash
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
```

Configure UFW on Lenovo Tiny to restrict SSH to WireGuard subnet only:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from 10.100.0.0/24 to any port 22 proto tcp
sudo ufw --force enable
sudo ufw status verbose
```

Delete local private key file on Lenovo after config is installed:

```bash
rm ~/wireguard-local/wg-prod-peer-home-lenovo-tiny-01.private
```

Validation from Hetzner hub:

```bash
sudo wg show
ping 10.100.0.3
```

Validation from laptop (requires Step 4b forwarding enabled):

```powershell
ping 10.100.0.3
ssh admin@10.100.0.3
```

Expected: handshake visible in `wg show` on hub, ping succeeds, SSH login works over tunnel.

## Step 4d: Full system validation (laptop → VPS → Lenovo Tiny)

**Prerequisite:** Step 4c must be complete. Both peers (laptop and Lenovo) must be online.

Validate the complete end-to-end path. Run these tests in order from your laptop:

### Verify tunnel is active

On laptop, confirm WireGuard profile `wg-prod-peer-admin-laptop-01` shows "Active" in WireGuard UI.

On VPS:

```bash
sudo wg show
```

Expected: both laptop and Lenovo peers show recent handshakes and data transfer.

### Test direct VPS reachability

From laptop (using SSH config alias):

```powershell
ping 10.100.0.1
ssh hetzner-wg "hostname; uname -a"
```

Or explicitly with SSH key:

```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519_hetzner_admin_laptop_01" admin@10.100.0.1 "hostname; uname -a"
```

Expected: ping succeeds, SSH login works without password, output shows Hetzner VPS hostname.

### Test Lenovo Tiny reachability (requires Step 4b enabled)

From laptop (using SSH config alias):

```powershell
ping 10.100.0.3
ssh lenovo-wg "hostname; uname -a"
```

Or explicitly with SSH key:

```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519_hetzner_admin_laptop_01" enteklasse@10.100.0.3 "hostname; uname -a"
```

Expected: ping succeeds, SSH login works without password, output shows Lenovo Tiny hostname.

### Validate return path (hub perspective)

On VPS:

```bash
sudo wg show wg0
sudo iptables -L FORWARD -v -n | head -20
sudo sysctl net.ipv4.ip_forward
```

Expected:
- Both peers show recent data transfer
- `ip_forward` is 1 (enabled)
- Forward chain shows traffic passing through

### Test SSH access restrictions

Before Step 5 is applied, SSH is open on public IP.
After Step 5, it will be restricted to WireGuard tunnel only.

Confirm `ufw` rules match plan:

```bash
sudo ufw status verbose
```

Expected before Step 5: `22/tcp` and `51820/udp` both open from anywhere.

## Step 5: Restrict SSH to tunnel only

After successful VPN SSH validation:

```bash
sudo ufw delete allow 22/tcp
sudo ufw allow from 10.100.0.0/24 to any port 22 proto tcp
sudo ufw status verbose
```

Check from non-VPN path that public SSH no longer works.

## Step 6: Decommission old endpoint

Run on old VPS (if still reachable):

```bash
sudo systemctl disable --now wg-quick@wg0
sudo ufw delete allow 51820/udp
sudo rm -f /etc/wireguard/wg0.conf /etc/wireguard/*.key /etc/wireguard/*.private /etc/wireguard/*.public
sudo ss -lunpt | grep 51820 || true
```

Success criteria:

- no WireGuard listener on old endpoint
- no old peer keys left active
- old public endpoint removed from all client configs

## Step 7: Evidence capture

Capture and store:

- `sudo wg show`
- `sudo ufw status verbose`
- SSH over tunnel success screenshot/log
- Public SSH deny test result

Suggested evidence file:

- docs/security/evidence/wireguard-cx23-go-live-YYYY-MM-DD.md

## Rollback window

- Keep old endpoint powered for max 24 hours only if needed for rollback
- Do not reuse old keys even during rollback
- If rollback is needed, use newly generated keys and documented temporary endpoint
