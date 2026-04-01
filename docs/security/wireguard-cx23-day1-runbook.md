# WireGuard CX23 Day-1 Runbook

## Scope

- New clean rollout on Hetzner CX23
- Canonical WireGuard subnet: 10.100.0.0/24
- First iteration: WireGuard + SSH only
- No reverse proxy or public app exposure

## Preconditions

- Hetzner CX23 provisioned with Ubuntu 22.04 LTS
- You have SSH access as root (first login only)
- Local peer key pair is generated on laptop and stored safely
- Old endpoint credentials are considered compromised and will be rotated

## Address plan

- VPS hub: 10.100.0.1/24
- Laptop peer: 10.100.0.2/32
- Lenovo Tiny peer: 10.100.0.3/32
- Optional mobile/emergency peer: 10.100.0.4/32

Use this as the canonical allocation order for the first rollout. Keep peer IPs stable once assigned.

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

Validation:

```bash
ssh admin@<CX23_PUBLIC_IP>
```

## Step 2: Firewall baseline

Run on VPS as admin with sudo:

```bash
sudo apt update
sudo apt install -y ufw wireguard wireguard-tools
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 51820/udp
sudo ufw --force enable
sudo ufw status verbose
```

Expected: only 22/tcp and 51820/udp allowed inbound.

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
sudo wg genkey | sudo tee /etc/wireguard/wg0.private | sudo wg pubkey | sudo tee /etc/wireguard/wg0.public
sudo chmod 600 /etc/wireguard/wg0.private
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

Replace `<SERVER_PRIVATE_KEY>` with the content of `/etc/wireguard/wg0.private`.

Start service:

```bash
sudo wg-quick up wg0
sudo systemctl enable wg-quick@wg0
sudo wg show
```

## Step 4: Configure laptop peer

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

Validation from laptop:

```powershell
ping 10.100.0.1
ssh admin@10.100.0.1
```

Validation on VPS:

```bash
sudo wg show
```

Expected: recent handshake and data transfer counters on laptop peer.

## Step 4b (optional): Enable peer-to-peer routing via hub (laptop <-> Lenovo)

Use this only when you need laptop to reach Lenovo Tiny through Hetzner.
For management-only rollout, skip this step.

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
