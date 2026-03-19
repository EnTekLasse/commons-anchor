# H1 Pre-Hardware Checklist (WireGuard + SSH Hardening Prep)

Use this checklist to complete H1 before production hardware is available.

## Scope

- Phase: pre-hardware planning and validation prep
- Target item: H1 in delivery model
- Goal: be ready for fast and safe go-live when host hardware is available

## 1) Architecture decision

- [x] Endpoint placement selected:
  - [x] Host-level WireGuard (preferred)
  - [x] Container fallback (documented rationale)
- [x] Decision rationale documented (security, operability, maintenance)
- [x] Decision date recorded
- [x] Decision owner recorded

Decision notes:
- Owner: lasse
- Date: 2026-03-19
- Chosen option: Host-level WireGuard on production Ubuntu host.
- Rationale: Host-level setup has fewer moving parts and clearer network control. Container fallback is kept as contingency if host setup is blocked by environment constraints.

## 2) Peer inventory

- [x] Peer list created
- [x] Each peer has owner
- [x] Each peer has revoke contact path
- [x] Emergency backup peer policy defined

Peer table:

| Peer | Device Type | Owner | AllowedIPs Scope | Revoke Contact |
|---|---|---|---|---|
| laptop-main | laptop | lasse | server LAN only (no full-tunnel by default) | rotate+revoke via local runbook, owner: lasse |
| mobile-main | phone | lasse | server LAN only (no full-tunnel by default) | rotate+revoke via local runbook, owner: lasse |
| backup-peer | backup | lasse | disabled by default; enable only during incident recovery | rotate+revoke via local runbook, owner: lasse |

## 3) AllowedIPs policy

- [x] Least-privilege rule documented
- [x] No broad wildcard ranges unless explicitly justified
- [x] Example values documented per peer type

Policy notes:
- Laptop: Allow only private server management subnet; no 0.0.0.0/0 route by default.
- Mobile: Same as laptop, restricted to server management subnet and required admin endpoints.
- Backup: Disabled profile by default; temporary narrow scope during emergency only.
- Exceptions: Full-tunnel mode can be enabled temporarily for travel or hostile networks, but must be time-boxed and documented in incident/ops notes.

## 4) Key lifecycle

- [x] Key generation procedure documented
- [x] Key storage location/policy documented
- [x] Rotation cadence defined
- [x] Lost-device revoke procedure documented
- [x] One dry-run revoke scenario described

Procedure notes:
- Generate:
  - Server (Ubuntu host):
    - `umask 077`
    - `wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key`
  - Peer (example):
    - `wg genkey | tee laptop-main_private.key | wg pubkey > laptop-main_public.key`
- Store:
  - Private keys only on the owning device/host, never in git, chat, or screenshots.
  - Server private key path target: `/etc/wireguard/server_private.key` with `600` permissions.
  - Public keys may be stored in runbook/config inventory.
- Rotate:
  - Planned cadence: every 180 days or immediately after suspected compromise.
  - Rotation sequence: generate new peer key pair -> update server peer config -> restart/toggle peer -> verify tunnel -> retire old key.
- Revoke:
  - Lost/compromised device: remove peer from server config, apply config, invalidate old key, document timestamp and owner.
  - Example apply flow:
    - `sudo wg set wg0 peer <peer_public_key> remove`
    - `sudo wg show`

Dry-run scenario:
- Simulate `mobile-main` lost: remove peer key from active config, confirm peer can no longer establish tunnel, record incident note and recovery path.

## 5) Firewall and SSH policy draft

- [x] WireGuard UDP ingress rule drafted
- [x] SSH LAN-only enforcement rule drafted
- [x] Public SSH exposure explicitly denied in draft
- [x] Rule ownership documented

Draft rule notes:
- WireGuard port:
  - `51820/udp` (default, can be changed if conflict exists).
  - UFW example: `sudo ufw allow 51820/udp`
- Allowed source policy:
  - Initial pre-hardware baseline: allow from internet to WireGuard UDP only.
  - SSH must never be opened broadly on WAN.
- SSH LAN CIDR:
  - Planned management subnet: `192.168.1.0/24` (adjust to real LAN during go-live).
  - UFW example: `sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp`
- Explicit deny statement:
  - Do not permit public SSH (`22/tcp`) from `0.0.0.0/0`.
  - If needed, enforce deny rule: `sudo ufw deny 22/tcp`

Rule ownership:
- Owner: lasse
- Review cadence: at every key rotation event and before production host cutover.

## 6) Incident playbook

- [x] Lost device scenario documented
- [x] Compromised key scenario documented
- [x] Emergency disable sequence documented
- [x] Recovery/reenrollment sequence documented

Playbook notes:
- Incident trigger:
  - Peer device lost/stolen.
  - Suspected private key leak (logs, config leak, unexpected handshake activity).
- Immediate actions:
  1. Identify affected peer by name/public key.
  2. Remove peer from active interface config:
     - `sudo wg set wg0 peer <peer_public_key> remove`
  3. Verify peer removed:
     - `sudo wg show`
  4. Record incident timestamp and operator notes.
- Communication path:
  - Owner: lasse
  - Internal record: update this checklist + WireGuard runbook section with incident ID/date.
  - If external services are involved (DDNS/cloud), rotate account credentials if compromise scope is unclear.
- Recovery steps:
  1. Generate new key pair for replacement device.
  2. Update peer config with new public key and scoped AllowedIPs.
  3. Re-enable peer and validate tunnel/SSH over private path.
  4. Confirm old key no longer accepted.
  5. Close incident with post-incident summary and follow-up actions.

## 7) Go-live validation prep

- [x] Hardware-day validation script/checklist drafted
- [x] Tunnel establishment test step written
- [x] SSH over tunnel test step written
- [x] Public SSH closed test step written
- [x] Revoke test step written
- [x] Evidence capture format defined

Validation notes:
- Tunnel test:
  1. Start WireGuard on host and peer.
  2. Verify handshake and tunnel IP assignment (`wg show`, peer client status).
  3. Confirm peer can ping host tunnel IP.
- SSH private test:
  1. Connect SSH using private/tunnel address only.
  2. Verify successful key-based login.
  3. Record server-side SSH auth log snippet.
- Public SSH deny test:
  1. Attempt SSH to host public endpoint from non-allowed path.
  2. Confirm connection fails (timeout/refused).
  3. Confirm UFW/host firewall rules still match draft policy.
- Revoke test:
  1. Revoke one test peer key (`wg set wg0 peer <peer_public_key> remove`).
  2. Confirm revoked peer cannot re-establish tunnel.
  3. Restore access with new keypair and confirm successful reconnect.
- Evidence location:
  - Store outputs in runbook section or dated evidence note, for example:
    - `docs/security/evidence/wireguard-go-live-YYYY-MM-DD.md`
  - Include: command, timestamp, expected result, actual result, pass/fail.

Supporting docs:
- [docs/security/evidence/wireguard-go-live-YYYY-MM-DD.md](docs/security/evidence/wireguard-go-live-YYYY-MM-DD.md)
- [docs/security/wireguard-client-laptop-prep.md](docs/security/wireguard-client-laptop-prep.md)

Hardware-day command shortlist (reference):
- `sudo wg show`
- `sudo ss -lunpt | grep 51820`
- `sudo ufw status verbose`
- `ssh <user>@<private_tunnel_ip>`

## Completion gate (Pre-Hardware Done)

Mark H1 pre-hardware as done only when:

- [ ] Sections 1-7 are complete
- [ ] No unresolved blockers remain
- [ ] Decision owner signs off readiness

Sign-off:
- Owner:
- Date:
- Status: Ready for hardware phase / Not ready
