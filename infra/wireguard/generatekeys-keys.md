# WireGuard key generation

All keys are generated locally and must NEVER be committed.

## Naming convention

Use this format for exported key files:

`wg-<env>-<role>-<node>.<ext>`

Where:
- `<env>` = `prod`, `lab`, or `dr`
- `<role>` = `hub` or `peer`
- `<node>` = stable device name, not a temporary description
- `<ext>` = `private` or `public`

Recommended node names for current setup:
- Hetzner VPS: `hetzner-cx23-01`
- Lenovo Tiny at home: `home-lenovo-tiny-01`
- Windows laptop: `admin-laptop-01`

Examples:
- `wg-prod-hub-hetzner-cx23-01.private`
- `wg-prod-hub-hetzner-cx23-01.public`
- `wg-prod-peer-home-lenovo-tiny-01.private`
- `wg-prod-peer-home-lenovo-tiny-01.public`
- `wg-prod-peer-admin-laptop-01.private`
- `wg-prod-peer-admin-laptop-01.public`

Rule of thumb:
- The Hetzner VPS is the WireGuard `hub`.
- Lenovo Tiny and laptop are both `peer` nodes.
- Do not call both Hetzner and Lenovo `server` in key filenames.

## Server keys
```bash
cd /etc/wireguard
umask 077
wg genkey | tee wg-prod-hub-hetzner-cx23-01.private | wg pubkey > wg-prod-hub-hetzner-cx23-01.public
```

## Peer keys (example: laptop)
```bash
wg genkey | tee wg-prod-peer-admin-laptop-01.private | wg pubkey > wg-prod-peer-admin-laptop-01.public
```

## Bootstrap scripts (preferred)

Generate keys + peer config in one step.

PowerShell (Windows):
```powershell
./scripts/testing/bootstrap_wg_peer.ps1 -ClientNodeName admin-laptop-01 -PeerIpCidr 10.100.0.2/32 -ServerEndpoint <CX23_PUBLIC_IP>:51820 -ServerPublicKey <SERVER_PUBLIC_KEY>
```

Bash (Linux/macOS):
```bash
./scripts/testing/bootstrap_wg_peer.sh admin-laptop-01 10.100.0.2/32 <CX23_PUBLIC_IP>:51820 <SERVER_PUBLIC_KEY>
```

Both scripts output to wireguard-local by default and refuse to overwrite existing files.