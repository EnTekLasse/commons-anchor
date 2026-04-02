# WireGuard – VPS-based setup

This repository documents my **WireGuard setup using an EU-based VPS as a central hub**.
The goal is both **practical remote access** and **hands-on learning** in networking, security, and Linux.

---

## High-level architecture

            Internet
                |
            [ VPS ]
        (Public IPv4, EU)
                |
          WireGuard (UDP)
                |
        [ Home Network ]

- The VPS has a **public IPv4** and is always reachable
- The home network has **no direct inbound exposure**
- WireGuard is used as a **control and management tunnel**, not a full internet gateway

---

## Goals of this setup

- ✅ Learn WireGuard in practice (keys, peers, routing)
- ✅ Understand hub-and-spoke topology
- ✅ Avoid CGNAT issues without buying a static IPv4 from the ISP
- ✅ Keep the setup simple and understandable
- ✅ Expose only a single UDP port on the VPS

---

## Roles

### VPS (Hub)
- Target platform: **Hetzner CX23**
- Public IPv4
- WireGuard server
- Central entry point
- Runs **no application services** in the first iteration

### Home network (Peer)
- Always initiates the outbound connection
- Exposes no services directly to the internet
- Reachable only via WireGuard from the VPS

---

## Design principles

- **Least privilege**
  - Only required IP ranges are routed
  - No default route through the VPN
- **Single responsibility**
  - VPS = network control, not “cloud server for everything”
- **Reproducibility**
  - Configuration is documented, not remembered
- **Debuggability**
  - No NAT tricks or tunneling on top of tunneling

---

## IP plan (example)

| Node         | WireGuard IP |
|--------------|--------------|
| VPS          | 10.100.0.1   |
| Admin laptop | 10.100.0.2   |
| Lenovo Tiny  | 10.100.0.3   |

Subnet: `10.100.0.0/24`

Use `/32` addresses on peers and keep assignments stable once a peer is in service.

---

## Traffic model

- ✅ VPS → home network (management, ping, SSH, etc.)
- ✅ Home network → VPS
- ❌ No automatic routing of client internet traffic
- ❌ No full-tunnel / “VPN all traffic”

This is **intentional** to keep complexity low.

---

## Security

- WireGuard uses **public key authentication**
- No passwords
- No TLS certificates
- Only a single UDP port open on the VPS
- VPS firewall allows only:
  - SSH
  - WireGuard

## Firewall (UFW) - design and rationale

### Status

UFW is active and follows a default-deny model:

```text
Status: active
Default: deny (incoming), allow (outgoing), deny (routed)
```

### Allowed services (INPUT)

```text
22/tcp       ALLOW IN    Anywhere    # SSH
51820/udp    ALLOW IN    Anywhere    # WireGuard
```

- SSH is explicitly open for administration
- WireGuard UDP is open for VPN handshake
- No other services are exposed directly on the VPS

### Routed traffic (FORWARD) for WireGuard

```text
Anywhere     ALLOW FWD   Anywhere on wg0
```

This is the key rule when `wg0` is used as a routed interface:

- Traffic enters on `wg0`
- Traffic must be forwarded to another interface (for example `eth0`)
- This is FORWARD traffic, not INPUT traffic

UFW default policy is `deny (routed)`, so this rule is required:

```bash
sudo ufw route allow in on wg0
```

Without this, WireGuard can appear unstable: it may work before reboot, then fail after reboot due to routed traffic being blocked.

### Design choices

- UFW is used for host-level filtering
- Hetzner Cloud Firewall can be used as an additional protection layer
- UFW changes are tested while KVM/console access is available to avoid lockout

## WireGuard service management
WireGuard is managed via systemd using wg-quick.

Service name: `wg-quick@wg0.service`

### Start / stop manually
```bash
sudo systemctl start wg-quick@wg0
sudo systemctl stop wg-quick@wg0
```

Enable autostart at boot
```bash
sudo systemctl enable wg-quick@wg0
```

Status and health checks
```bash
sudo systemctl status wg-quick@wg0
sudo wg show
ip a show wg0
```

### Boot behavior

- WireGuard starts automatically on boot
- The home server always initiates the tunnel
- The VPS never initiates outbound connections to home

If WireGuard fails to start at boot:
```bash
sudo journalctl -u wg-quick@wg0 -b
```

### Recovery & failsafe
If WireGuard is misconfigured or fails to come up:

1. Access the machine locally (physical console or Hetzner KVM)
2. Bring the interface down:

```bash
sudo wg-quick down wg0
```

3. Fix `/etc/wireguard/wg0.conf`
4. Restart the service:

```bash
sudo systemctl start wg-quick@wg0
```

If firewall rules lock you out, recover via console:

```bash
sudo ufw disable
```

The system is intentionally designed so that loss of WireGuard does not block local access.
---

## What is intentionally not done (yet)

- ❌ Reverse proxy (Caddy/Nginx)
- ❌ Monitoring (Uptime Kuma)
- ❌ Backup target
- ❌ Additional peers (laptop / phone)

These will be added later, **one step at a time**.

---

## Possible future extensions

- Reverse proxy on VPS → services at home
- Monitoring from VPS → home network
- Additional WireGuard peers (mobile clients)
- Firewall tightening and logging
- Troubleshooting documentation (ping, tcpdump, `wg show`)

---

## Status

🟢 **First iteration**
- Focus: understanding and stable connectivity
- No automation or “smart” tooling yet
- Deployment decision: clean restart on Hetzner CX23 using subnet `10.100.0.0/24`