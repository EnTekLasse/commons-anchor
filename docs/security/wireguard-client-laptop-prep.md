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

Use a role-based pattern instead of generic names like `server` and `client`:

`wg-<env>-<role>-<node>`

Where:
- `<env>` = `prod`, `lab`, or `dr`
- `<role>` = `hub` for the public WireGuard entry point, `peer` for every connected device
- `<node>` = stable machine name

Recommended node names in this project:
- Hetzner VPS hub: `hetzner-cx23-01`
- Home Lenovo Tiny peer: `home-lenovo-tiny-01`
- Admin laptop peer: `admin-laptop-01`

Recommended profile and key labels:
- WireGuard profile in app: `wg-prod-peer-admin-laptop-01`
- Laptop key files: `wg-prod-peer-admin-laptop-01.private` and `wg-prod-peer-admin-laptop-01.public`
- Hetzner key files: `wg-prod-hub-hetzner-cx23-01.private` and `wg-prod-hub-hetzner-cx23-01.public`
- Lenovo Tiny key files: `wg-prod-peer-home-lenovo-tiny-01.private` and `wg-prod-peer-home-lenovo-tiny-01.public`

Current canonical identity for this PC:
- `wg-prod-peer-admin-laptop-01`

Reasoning:
- The WireGuard topology has one `hub` and multiple `peer` nodes.
- Both Hetzner and Lenovo are servers in a general sense, but only Hetzner is the VPN hub.
- This avoids confusion during revocation, rotation, and peer inventory reviews.

Server-side (Ubuntu host):

| File | Convention | Example |
| --- | --- | --- |
| Hub config | `wg0.conf` | `/etc/wireguard/wg0.conf` |
| Hub private key | `wg-<env>-hub-<node>.private` | `wg-prod-hub-hetzner-cx23-01.private` |
| Peer public keys | embedded in `wg0.conf` as `[Peer]` block | One block per device |

Client-side (Windows laptop, phone, etc.):

| File | Convention | Example |
| --- | --- | --- |
| Peer config | `wg-<env>-peer-<node>.conf` | `wg-prod-peer-admin-laptop-01.conf` |
| Client private key | generated inside WireGuard app, never exported | — |

Key generation rules:
- Generate keys on the device that will use them.
- Never copy private keys over the network or paste them into chat.
- Import config from file into the WireGuard client, then delete the source file.
- Use the profile name `wg-prod-peer-admin-laptop-01` in the WireGuard client UI (matches section 4).
## 4) Connection profile prep

- [x] Define profile name convention (for example: `wg-prod-peer-admin-laptop-01`).
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
- Profile name: `wg-prod-peer-admin-laptop-01`
- Interface Address: `10.100.0.2/32`
- DNS: `1.1.1.1` (or internal DNS when available)
- AllowedIPs baseline: `10.100.0.0/24` for hub-and-spoke peer reachability via Hetzner
- Full-tunnel mode (`0.0.0.0/0`) is exception-only and must be time-boxed.
- PersistentKeepalive: `25` (for NAT stability)

### Bootstrap script (recommended)

You can generate key pair + ready config in one command.

PowerShell (Windows):
- `./scripts/testing/bootstrap_wg_peer.ps1 -ClientNodeName admin-laptop-01 -PeerIpCidr 10.100.0.2/32 -ServerEndpoint <CX23_PUBLIC_IP>:51820 -ServerPublicKey <SERVER_PUBLIC_KEY>`

Bash (Linux/macOS):
- `./scripts/testing/bootstrap_wg_peer.sh admin-laptop-01 10.100.0.2/32 <CX23_PUBLIC_IP>:51820 <SERVER_PUBLIC_KEY>`

Defaults used by both scripts:
- Output folder:
  - Windows: `%USERPROFILE%\\Documents\\wireguard-local\\`
  - Linux/macOS: `~/wireguard-local/`
- AllowedIPs: `10.100.0.0/24`
- DNS: `1.1.1.1`
- Keepalive: `25`

Safety behavior:
- Script stops if output files already exist (no overwrite).
- Script requires endpoint and server public key (no placeholders).
- Generated files follow `wg-<env>-<role>-<node>.*` naming.

### Rotation and old-key cleanup (when ready)

Use this sequence for safe rotation on this laptop:
1. Generate a fresh profile with the bootstrap script using the same node name (`admin-laptop-01`) and a new peer IP only if needed.
2. Add the new public key to VPS `wg0.conf` and apply server config.
3. Activate the new profile and confirm tunnel + SSH works.
4. Remove old peer key from server (`wg set wg0 peer <old_public_key> remove`).
5. Delete old local key/config files from `wireguard-local` only after validation.

Windows cleanup reference:
- List local WireGuard artifacts:
  - `Get-ChildItem "$env:USERPROFILE\Documents\wireguard-local" -Filter "wg-*-admin-laptop-01.*"`
- Delete only outdated files (example):
  - `Remove-Item "$env:USERPROFILE\Documents\wireguard-local\wg-prod-peer-admin-laptop-01.old.*" -Force`

Important:
- Never delete the currently active profile files until the new profile is verified.
- Keep one short rollback window (for example, 24 hours) before final deletion.

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

## 5a) Process Notes: Stable SSH over WireGuard (Windows -> Hetzner)

Context:
- WireGuard and SSH configuration itself was straightforward.
- The practical challenge was Windows client behavior: identity selection, missing keepalive, implicit SSH client configuration, and unclear route verification.
- Conclusion: Stable operations require deterministic client behavior, not only correct server configuration.
- For the broader management-plane model and route-verification method, see `docs/security/wireguard-remote-access.md`.

### Observation 1: SSH can work via public IP but fail via WireGuard

- SSH could be stable against the public IP while being unstable against `10.100.0.1`.
- The root cause was Windows OpenSSH client behavior (key selection per destination), not WireGuard cryptography or topology.
- Implicit default behavior is not reliable enough for secure management access.

### Observation 2: Explicit SSH client configuration was required

It was necessary to create an explicit `~/.ssh/config` and force identity usage:

```sshconfig
Host *
    ServerAliveInterval 30
    ServerAliveCountMax 10

Host hetzner-wg
    HostName 10.100.0.1
    User root
    IdentityFile ~/.ssh/id_ed25519_hetzner_admin_laptop_01
    IdentitiesOnly yes
```

Without `IdentityFile` + `IdentitiesOnly yes`, the client may try the wrong key or multiple keys in sequence, which can produce misleading errors (for example password prompts or `Permission denied`).

### Observation 3: Keepalive was critical on Windows (not optional)

Without keepalive, the following issues were observed:
- Frozen PowerShell/Terminal sessions after idle time
- Connections dropped without clear errors
- Ghost sessions left on the server
- Confusing troubleshooting across WireGuard vs SSH vs terminal behavior

Required global settings:
- `ServerAliveInterval 30`
- `ServerAliveCountMax 10`

This is a stability prerequisite on Windows over VPN, not a performance optimization.

### Observation 4: Host alias improved both ergonomics and verification

The `hetzner-wg` alias provided:
- Consistent usage: `ssh hetzner-wg`
- Lower risk of testing the wrong destination
- An explicit expectation of WireGuard routing because `HostName` points to `10.100.0.1`

### Observation 5: Route verification required server-side observation

The client does not always clearly show which interface or route SSH actually used.
So route verification was done on the server:

```bash
who
echo "$SSH_CONNECTION"
```

Expected result for correct WireGuard routing:
- Source IP is the peer tunnel IP (for example `10.100.0.2`)
- Not the public client IP

`It works` is not sufficient evidence in a security setup without route proof.

### Overall learning

The difficult part of secure management access is determinism, not base configuration.

On Windows over WireGuard, the following must be explicit:
- SSH client configuration
- Identity selection
- Keepalive
- Route verification

These are not optional conveniences. They are required for stable and understandable operations.

## 5b) Caveat: Windows WireGuard GUI caches configuration state

Important when changing `.conf` files:

One-time actions that may not take effect properly:
- Editing `.conf` and re-importing same filename
- Deactivate/Activate tunnel (may use cached state)

Reliable method for configuration changes:
1. Delete the profile in WireGuard GUI.
2. Delete the `.conf` file locally.
3. Generate or edit a fresh `.conf`.
4. Import again into WireGuard.

Common scenario:
- You change `AllowedIPs` in the `.conf`.
- You re-import without deletion.
- Tunnel still uses old `AllowedIPs`.
- Appears to be a VPN issue, but is actually GUI state caching.

Workaround when troubleshooting:
- Always delete and re-import on Windows if configuration behavior seems inconsistent.

## 6) Revoke drill (client perspective)

- [ ] Confirm expected behavior after server-side peer revoke (tunnel fails to connect).
- [ ] Re-import updated profile with new keypair.
- [ ] Confirm reconnect and SSH success.

## Sign-off

- Owner:
- Date:
- Client-ready status: Ready / Blocked
- Notes:
