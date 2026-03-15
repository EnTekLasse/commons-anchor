# Ubuntu Server Plan (Lenovo Tiny)

## Goal
Run a stable home-lab server that can host the data stack 24/7.

## Hardware target
- Lenovo Tiny (8+ cores recommended, 32GB RAM target)
- 1TB NVMe SSD (or more)
- Wired ethernet only
- UPS is recommended for graceful shutdown

## Installation steps
1. Install Ubuntu Server LTS (current stable LTS)
2. Create non-root admin user and disable password login for SSH
3. Install updates and reboot
4. Configure static DHCP reservation in router
5. Install Docker Engine + compose plugin
6. Clone this repo and create production .env
7. Start stack with docker compose up -d

## Baseline hardening checklist
- UFW: allow only SSH from WireGuard subnet and required ports
- SSH: key-only auth, disable root login
- fail2ban enabled for SSH
- unattended-upgrades enabled
- filesystem snapshots or regular backups

## Ops basics
- Daily logical backup of Postgres with retention
- Weekly restore test on a disposable instance
- Disk and memory monitoring in Grafana
- Alerting for container restarts and DB health

## Project evidence
- Keep before/after architecture diagrams
- Save screenshots of dashboards and uptime
- Document one incident and your resolution process
