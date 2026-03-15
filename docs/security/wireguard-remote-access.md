# WireGuard Remote Access Plan

## Objective
Secure remote administration access without exposing SSH directly to the public internet.

Related local credential handling:
- [docs/security/local-secrets-baseline.md](docs/security/local-secrets-baseline.md)

## Design
- WireGuard endpoint on home server or router
- SSH listens on LAN only
- Remote laptop/phone enters VPN first, then SSH to server private IP

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
- Host WireGuard on Ubuntu host vs container
- Use dynamic DNS provider or fixed public IP
- Multi-peer policy (laptop, mobile, backup device)
