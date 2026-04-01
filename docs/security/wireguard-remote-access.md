# WireGuard Remote Access Plan

## Objective
Secure remote administration access without exposing SSH directly to the public internet.

Related local credential handling:
- [docs/security/local-secrets-baseline.md](docs/security/local-secrets-baseline.md)

H1 pre-hardware checklist artifact:
- [docs/security/wireguard-h1-prehardware-checklist.md](docs/security/wireguard-h1-prehardware-checklist.md)

Day-1 execution runbook:
- [docs/security/wireguard-cx23-day1-runbook.md](docs/security/wireguard-cx23-day1-runbook.md)

## Design
- WireGuard endpoint on Hetzner CX23 VPS (hub model)
- Home network and admin clients are peers behind the hub
- SSH to VPS is restricted to VPN addresses after tunnel validation
- First iteration is management-only (no reverse proxy or app exposure)

## Canonical IP allocation policy

Tunnel subnet:
- `10.100.0.0/24`

Current static assignments:
- Hetzner hub: `10.100.0.1/24`
- Admin laptop peer: `10.100.0.2/32`
- Lenovo Tiny peer: `10.100.0.3/32`

Reserved next addresses:
- Mobile or emergency peer: `10.100.0.4/32`

Allocation rules:
- Hub always keeps `.1` on the tunnel subnet.
- Each peer gets one unique `/32` address.
- Peer addresses are treated as stable identities and should not be reused casually.
- Management SSH targets the hub at `10.100.0.1`; peer-to-peer routing is added only when explicitly needed.

## Minimal flow
1. Connect VPN client
2. Confirm private tunnel IP
3. SSH using private address

## Process notes: Establishing and verifying WireGuard management access

### Context
- WireGuard is well documented as a technology, but the practical challenges in this setup were not the base configuration.
- The key challenges were management-plane usage, route proof, WireGuard/SSH interaction on clients, and assumptions carried over from classic VPN tools.
- These points are usually implicit in standard guides and must be made explicit for reliable operations.

### 1) WireGuard is a network interface, not a session

WireGuard:
- Creates a network interface (`wg0`)
- Provides a private IP space
- Does not provide classic session semantics (no OpenVPN-like connected/disconnected state)

Operational consequence:
- `WireGuard is running` is not the same as `my SSH is using WireGuard`.
- Once the interface is up, path selection depends on routing and destination.

### 2) Private management IP is the source of truth

This project uses:
- Management address: `10.100.0.1`
- Address exists only on the WireGuard interface
- No DNS, NAT, or fallback for management path checks

Rule:
- If traffic reaches `10.100.0.1`, it is WireGuard path traffic.

This is important because:
- SSH user experience looks the same regardless of path.
- Client UX rarely states route selection explicitly.

### 3) Distinguish "works" from "works correctly"

Observed confusion pattern:
- SSH works via public IP
- SSH also works via `ssh hetzner-wg`
- Actual path can still be unclear without proof

Key distinction:
- Functionality: login succeeded
- Property: login used the intended management plane

### 4) Server-side verification is required

Final route verification should be done server-side:

```bash
who
echo "$SSH_CONNECTION"
```

Expected proof of correct path:
- Active session source IP is peer tunnel IP (for example `10.100.0.2`)
- Not public client IP

Why this matters:
- WireGuard is intentionally low-noise when healthy.
- There is no universal client-side indicator for "this TCP flow used wg0".

### 5) Concurrent public and VPN SSH sessions create noise

During troubleshooting, multiple concurrent sessions can cause false conclusions:
- Some sessions from public IP
- Some sessions from WireGuard IP

Operational rule:
- Clean up old sessions before route validation.
- Match the active TTY/session specifically to WireGuard source IP before concluding.

### 6) WireGuard and SSH often fail quietly

Meta-observation:
- WireGuard usually fails quietly.
- SSH over WireGuard often looks like ordinary SSH issues.
- Symptoms rarely identify VPN path assumptions directly.

Required method:
- Troubleshoot layer by layer: interface -> IP reachability -> SSH behavior.
- Validate each layer independently.

### 6a) Hub forwarding and peer return-path caveat (peer-to-peer traffic)

Important in hub-and-spoke topologies:
- Successful handshakes do not guarantee peer-to-peer reachability.
- The hub must have IPv4 forwarding enabled (`net.ipv4.ip_forward=1`) for traffic to traverse between peers.
- Each peer must include other peer destination IPs in `AllowedIPs` when peer-to-peer reachability is required.

Failure pattern to expect if this is missing:
- Handshakes look healthy in `wg show`.
- Direct peer reachability still fails.
- You may see destination unreachable behavior despite active tunnels.

Operational rule:
- Use peer `AllowedIPs = 10.100.0.0/24` when peers must reach each other through the hub.
- Restrict to narrower `/32` routes only when explicitly enforcing management-only paths.

### 7) Overall WireGuard learning

Core lesson:
- WireGuard gives prerequisites, not feedback.

A robust management setup requires:
- Unambiguous private addresses
- Unambiguous SSH destinations
- Server-side verification
- A clear mental model of what WireGuard does and does not do

### 8) Interaction with SSH client configuration

Practical stability came from combining:
- SSH alias (`hetzner-wg`) mapped to `10.100.0.1`
- Deterministic SSH identity selection (`IdentityFile` + `IdentitiesOnly`)
- Keepalive settings for stable Windows sessions

This made the WireGuard layer operationally trivial, which is the desired outcome for management access.

### Summary conclusion

The difficult part was not writing `wg0.conf`, but verifying correct path usage and avoiding false confidence based on "it works".
The value of these notes is operational determinism and verification discipline.

## Field validation report: Hub-and-spoke peer-to-peer routing (April 2026)

This section documents findings from the first multi-peer validation (laptop + Lenovo Tiny via Hetzner hub).

### 1) Network can be perfect while SSH still fails

Observed state:
- ✅ WireGuard handshakes 100% OK
- ✅ Routing tables correct
- ✅ Ping works
- ❌ SSH times out

Learning:
- Transport layer (WireGuard) and access layer (SSH) are intentionally separate concerns.
- Never use "SSH doesn't work" to debug VPN/routing issues; test ICMP first.

### 2) Destination host unreachable reveals the exact failure point

Observed:

```
Reply from 10.100.0.1: Destination host unreachable
```

This signal told us:
- ✅ Laptop → hub path works (hub responded)
- ❌ Hub → Lenovo return path broken
- 🎯 Root cause: Lenovo's firewall / sshd not running / AllowedIPs misconfiguration

Learning:
- The responder IP in an ICMP error tells you exactly where the packet died.
- Each layer's failure mode is distinct and diagnostic.

### 3) Windows WireGuard GUI caches routing state

Observed:
- Config changes in `.conf` → not always live
- Deactivate/Activate tunnel → sometimes uses stale state
- Delete profile + re-import `.conf` → only method that reliably reloads

Learning:
- On Windows, WireGuard configuration is not authoritative until the tunnel is deleted and re-imported.
- Changing AllowedIPs requires full tunnel cycle, not just reconnect.

### 4) Hub-and-spoke requires all three: AllowedIPs + forwarding + firewall policy

Required for peer-to-peer traffic through hub:

- ✅ Correct `AllowedIPs` in hub `wg0.conf` per peer
- ✅ `net.ipv4.ip_forward=1` on hub
- ✅ Firewall FORWARD policy not DROP (check `ufw default` and `iptables -L FORWARD`)

Missing any one causes silent failures despite healthy handshakes.

Learning:
- WireGuard is routing + encryption, not magic. Every layer must be explicitly configured.

### 5) sshd must actually be running

Observed:
- Lenovo was fully reachable on WireGuard
- `ping 10.100.0.3` worked
- `ssh 10.100.0.3` timed out
- Root cause: sshd service was not active

Learning:
- Network reachability is not the same as service availability.
- Verify service status before blaming VPN.

### 6) ssh -vvv is the final truth

Verbose output showed:

```
Offering public key: /home/user/.ssh/id_ed25519_lenovo_tiny ...
Server refused our key
```

Where regular SSH produced only "Permission denied".

Learning:
- If you do not see "Offering public key …" in `-vvv` output, the identity was never tried.
- Without verbose mode, you are guessing about key delivery.

### 7) SSH config matches only string keys, not "host intelligence"

Failure pattern:

```ini
Host lenovo-wg
	HostName 10.100.0.3
	User ubuntu
	IdentityFile ~/.ssh/id_ed25519_lenovo
```

Works:  `ssh lenovo-wg`  
Ignores config:  `ssh ubuntu@10.100.0.3` or `ssh 10.100.0.3`

Learning:
- SSH config hostnames are literal string matches, not intelligent hostname resolution.
- Use aliases consistently or config directives will not apply.

### 8) SSH keys are per-user, not per-machine

Observed:
- Correct key in `/home/ubuntu/.ssh/authorized_keys`
- SSH config used `User root`
- Result: SSH tried to log in as root, key not found, prompted for password

Learning:
- User and key path must match. SSH does exactly what you configure.

### 9) Standard user + sudo is the correct endpoint

Architecture decision:
- ✅ SSH login as unprivileged user (for example `ubuntu`)
- ✅ Use `sudo` when elevated access is needed
- ❌ Never default to root SSH

Learning:
- Root SSH is almost never necessary, even in private VPNs.
- Standard user + sudo maintains audit trail and forces explicit privilege escalation.

### Meta-learning: Determinism through layered testing

The difficult part was not WireGuard configuration, but isolating failures.

Test order:
1. Interface status: `ip link show wg0`
2. Routing: `ip route show`, `ip link show`, confirm tunnel target is routable
3. ICMP: `ping 10.100.0.X` (identifies exact failure point via error responder)
4. Service: `systemctl status sshd`, `netstat -ln | grep :22`
5. SSH identity: `ssh -vvv` to see which keys are offered
6. User match: Verify `User` in SSH config matches `authorized_keys` owner

Conclusion:
- Validate each layer independently.
- Never skip to application-layer troubleshooting before confirming network/service layers.

## Security controls
- Use key pairs only (no password auth)
- Rotate WireGuard peer keys if device is lost
- Restrict allowed IPs per peer
- Keep audit logs for SSH and VPN connections
- Add MFA on cloud account if using dynamic DNS

## Open decisions
- Resolved on 2026-04-01:
	- Use a new Hetzner CX23 VPS as clean replacement for legacy setup
	- Canonical tunnel subnet is 10.100.0.0/24
	- Scope is WireGuard + SSH only for first iteration

## Decommission note
- Legacy endpoint and keys from earlier attempts are treated as compromised and must be rotated.
- Client WireGuard runtime configs stay local only and are never committed.

## Pre-hardware checklist (can run now)

Use this checklist before the Lenovo Tiny is ready.

- [ ] Decide endpoint placement policy (host-level preferred, container fallback).
- [ ] Define peer inventory (laptop, mobile, emergency backup device).
- [ ] Define AllowedIPs policy per peer (least privilege, no broad wildcard ranges).
- [ ] Define key lifecycle policy (generation, storage, rotation, lost-device revoke).
- [ ] Draft firewall rule set for WireGuard UDP port and SSH LAN-only enforcement.
- [ ] Draft incident playbook for lost peer device and key revocation.
- [ ] Prepare validation script/checklist for first tunnel test on production hardware.

## Definition of Done (H1 pre-hardware)

H1 can be marked done for pre-hardware scope when all criteria below are met:

- [ ] Architecture decision is recorded for endpoint placement (host-first, container fallback with rationale).
- [ ] Peer inventory is finalized with owner and revoke contact per peer.
- [ ] AllowedIPs policy is documented with least-privilege examples for each peer type.
- [ ] Key lifecycle procedure is documented (generate, store, rotate, revoke) with command examples.
- [ ] Firewall policy draft is documented for WireGuard UDP ingress and SSH LAN-only access.
- [ ] Incident playbook exists for lost/stolen device and emergency key revoke.
- [ ] First-run validation checklist exists for production host execution day.

## Required evidence for completion

- [ ] A single checklist artifact is linked from this document (or embedded here).
- [ ] Command snippets are copy-paste ready and reviewed once for syntax.
- [ ] All open decisions in this file are either resolved or explicitly deferred with owner/date.

## Exit criteria to hardware phase

After Lenovo host is available, H1 transitions to go-live validation:

- [ ] Tunnel can be established from one peer device.
- [ ] SSH over private tunnel works and public SSH remains closed.
- [ ] Revoke test is executed for one peer key.
- [ ] Validation result is documented in the project runbook.
