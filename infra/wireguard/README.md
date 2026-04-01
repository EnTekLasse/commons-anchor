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