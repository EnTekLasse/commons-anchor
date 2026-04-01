# Lessons Learned

This document captures practical lessons learned during the implementation
and debugging of the remote access model.

These are not theoretical best practices, but **things that actually broke**.

---

## 1. WireGuard Handshakes Do Not Imply Access

A successful WireGuard handshake only proves:
- cryptographic authentication succeeded
- peers can exchange packets

It does **not** imply:
- routing is correct
- services are reachable
- login will succeed

Always validate layers independently.

---

## 2. Ping Errors Reveal Where Routing Fails

The source of a ping error matters.

Example:
- `Reply from 10.100.0.1: Destination host unreachable`
  → packet reached the hub
  → hub could not forward to the target

This is a routing or return-path issue, not a client issue.

---

## 3. Windows WireGuard GUI Caches State

On Windows:
- Deactivate/Activate may reuse old routing state
- Edited configs are not always applied

Reliable workflow:
- Delete tunnel
- Re-import updated config
- Activate

This is non-obvious and easy to misdiagnose.

---

## 4. Hub-and-Spoke Requires Forwarding *and* Policy

For peer-to-peer traffic via a hub, all of the following must be true:

- IP forwarding enabled
- Firewall allows forwarding
- Routing tables are correct

Missing any one results in silent failure.

---

## 5. A Node Can Be Reachable Without Offering Services

Network reachability does not imply service availability.

A system may:
- respond to WireGuard
- respond to ping
- yet offer no SSH service

Always verify that the service is actually running and listening.

---

## 6. `ssh -vvv` Is the Ground Truth

Verbose SSH output is definitive.

Key insights from `ssh -vvv`:
- which keys are offered
- which user is being authenticated
- why authentication falls back to password

If a key is not listed as "Offering public key", it is not in play.

---

## 7. SSH Config Applies Only When the Host Matches

SSH config entries are string matches.

- `Host lenovo-wg` applies only to `ssh lenovo-wg`
- It does not apply to `ssh user@10.100.0.3`

This is a common source of confusion.

---

## 8. SSH Keys Are Per User, Not Per Host

SSH authorization is user-specific.

Installing a key for:
- `enteklasse`

does not grant access to:
- `root`

If the client attempts the wrong user, key auth will fail correctly.

---

## 9. Root SSH Is Rarely Necessary

A safer and simpler pattern:
- SSH as a normal user
- Elevate via `sudo`

This reduces blast radius and simplifies key management.

---

## 10. Most “SSH Problems” Are Identity Problems

When SSH prompts for a password:
- the network is usually fine
- the server is usually fine

The most common causes are:
- wrong user
- wrong key
- wrong alias
- key not being offered

Debug identity before debugging networking.

---

## Summary

Most failures were not caused by bugs,
but by incorrect mental models.

Clarity about:
- layers
- responsibilities
- trust boundaries

proved more valuable than additional tooling.
