# Remote Access Model

## Purpose

The purpose of this document is to describe how remote administrative access is achieved in this project,
without exposing internal nodes or management services directly to the public internet.

The goal is not convenience-first access, but **predictable, auditable, and reversible access**.

---

## Design Goals

- No public SSH exposure on internal nodes
- Clear separation between:
  - transport security
  - identity and authorization
- Minimal attack surface
- Easy revocation if a device is lost or compromised
- Works across:
  - home networks
  - VPS environments
  - NAT and CGNAT scenarios

---

## High-Level Model

This project uses a **hub-and-spoke WireGuard topology**:

- A publicly reachable hub (VPS)
- Private nodes that never expose management services
- Admin devices that must authenticate into the private network first

Admin Laptop
|
| WireGuard (encrypted, authenticated)
|
Public Hub (VPS)
|
| WireGuard (private routing)
|
Private Node (e.g. Lenovo Tiny)

WireGuard provides **network reachability**, not login access.
SSH (or other services) provide **identity and authorization**.

---

## Mental Model: Transport vs Login

It is critical to keep these layers separate:

| Layer       | Responsibility                      |
|------------|-------------------------------------|
| WireGuard  | Who may send packets to whom        |
| Routing    | Where packets are allowed to go     |
| SSH        | Who is allowed to log in            |

A successful WireGuard handshake does **not** imply that:
- routing is correct
- services are running
- login will succeed

Each layer must be validated independently.

---

## Addressing Model

- Each WireGuard peer uses a `/32` address
- Routing is controlled explicitly via `AllowedIPs`
- The hub routes traffic between peers

Example:
- Admin laptop: `10.100.0.2/32`
- Hub: `10.100.0.1/24`
- Private node: `10.100.0.3/32`

This avoids implicit trust and prevents accidental lateral access.

---

## SSH Access Pattern

- SSH listens only on private interfaces
- Access is only possible **after** WireGuard connectivity is established
- Public SSH exposure is avoided entirely

Best practice:
- Login as a normal user
- Elevate via `sudo` when required
- Avoid direct root SSH access

---

## Key Separation

Two different key systems are in use:

### WireGuard Keys
- Device-level identity
- Control network reachability
- Revoked when a device is lost

### SSH Keys
- User-level identity
- Control login authorization
- Managed per user account

These keys serve different purposes and are intentionally not merged.

---

## Windows Client Notes

On Windows, the WireGuard GUI may retain cached routing state.

Important implications:
- Editing `AllowedIPs` is not always applied by deactivate/activate
- Deleting and re-importing the tunnel is the only reliable way to ensure a clean state

This behavior must be accounted for during debugging.

---

## Failure Modes (Non-Exhaustive)

Common failure modes include:
- Correct WireGuard handshake, but incorrect routing
- Routing correct, but service not running
- SSH key installed for the wrong user
- SSH config alias not matching the invoked host
- Client offering the wrong private key

These are addressed in `docs/lessons-learned.md`.

---

## Non-Goals

This document does **not** attempt to:
- Replace SSH with WireGuard-only identity
- Provide a general VPN guide
- Optimize for zero-click convenience

Security and clarity are prioritized over speed.

---

## Summary

Remote access in this project is intentionally layered:

1. Establish encrypted transport (WireGuard)
2. Validate routing and reachability
3. Authenticate user identity (SSH)
4. Elevate privileges explicitly if required

If any step is unclear, it should fail loudly and safely.