# WireGuard Client Prep (Windows Laptop)

This runbook covers what can be prepared now on the laptop side before server hardware is available.

## Scope

- Target device: current Windows laptop
- Goal: be client-ready for first tunnel test on hardware day

## 1) Install readiness

- [x] Confirm `winget` is available.
- [ ] Install WireGuard client when ready:
  - `winget install --id WireGuard.WireGuard --exact --scope user --accept-package-agreements --accept-source-agreements`
- [ ] Verify installation by opening WireGuard UI.

## 2) Local security baseline

- [ ] Ensure laptop login uses strong password/PIN.
- [ ] Enable full-disk encryption (BitLocker) if not already enabled.
- [ ] Ensure OS updates are current.
- [ ] Ensure endpoint protection is active.

## 3) Key handling policy (client side)

- [ ] Never store private keys in git repos, screenshots, or shared chat.
- [ ] Keep config export files in a controlled local folder only.
- [ ] Delete temporary key files after importing into WireGuard client.

Recommended local working folder:
- `%USERPROFILE%\\Documents\\wireguard-local\\`
## 3a) Naming convention

Consistent naming makes rotation and revocation unambiguous.

Server-side (Ubuntu host):

| File | Convention | Example |
| --- | --- | --- |
| Server config | `wg0.conf` | `/etc/wireguard/wg0.conf` |
| Server private key | `server-private.key` | Generated locally, never shared |
| Peer public keys | embedded in `wg0.conf` as `[Peer]` block | One block per device |

Client-side (Windows laptop, phone, etc.):

| File | Convention | Example |
| --- | --- | --- |
| Client config | `ca-<role>-<device>.conf` | `ca-admin-laptop.conf` |
| Client private key | generated inside WireGuard app, never exported | — |

Key generation rules:
- Generate keys on the device that will use them.
- Never copy private keys over the network or paste them into chat.
- Import config from file into the WireGuard client, then delete the source file.
- Use the profile name `ca-prod-laptop-main` in the WireGuard client UI (matches section 4).
## 4) Connection profile prep

- [x] Define profile name convention (for example: `ca-prod-laptop-main`).
- [ ] Prepare placeholder fields for:
  - Interface private key
  - Interface address
  - DNS
  - Peer public key
  - Endpoint
  - AllowedIPs
  - PersistentKeepalive
- [ ] Keep profile disabled until server-side go-live window.

Proposed defaults:
- Profile name: `ca-prod-laptop-main`
- Interface Address: `10.44.0.2/32` (example; align with server config)
- DNS: `1.1.1.1` (or internal DNS when available)
- AllowedIPs baseline: server management LAN only (example `192.168.1.0/24`)
- Full-tunnel mode (`0.0.0.0/0`) is exception-only and must be time-boxed.
- PersistentKeepalive: `25` (for NAT stability)

## 5) Hardware-day client test plan

- [ ] Start WireGuard tunnel and confirm connection state.
- [ ] Verify private route is installed.
- [ ] Test SSH over private tunnel to server private IP.
- [ ] Confirm no dependency on public SSH path.
- [ ] Capture evidence in `docs/security/evidence/wireguard-go-live-YYYY-MM-DD.md`.

Hardware-day Windows command sequence (reference):
1. Verify WireGuard tunnel status in UI (Connected + recent handshake).
2. Check local IP and route:
  - `ipconfig`
  - `route print`
3. Test private path reachability:
  - `ping <server_tunnel_ip>`
4. Test SSH over private tunnel:
  - `ssh <user>@<server_private_or_tunnel_ip>`
5. Verify public SSH is not relied on:
  - `Test-NetConnection <public-host-or-ip> -Port 22`
6. Record outputs in evidence file.

## 6) Revoke drill (client perspective)

- [ ] Confirm expected behavior after server-side peer revoke (tunnel fails to connect).
- [ ] Re-import updated profile with new keypair.
- [ ] Confirm reconnect and SSH success.

## Sign-off

- Owner:
- Date:
- Client-ready status: Ready / Blocked
- Notes:
