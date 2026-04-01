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

## Minimal flow
1. Connect VPN client
2. Confirm private tunnel IP
3. SSH using private address

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
