# Proxmox API Reliability Implementation Plan

> Use `subagent-driven-development` to implement the tasks. Track completion with checkboxes.

**Goal:** Reuse valid API connections and retrieve completed command results after a lost reply.

**Architecture:** The Proxmox overlay corrects proxy headers and saves command results. The Go provider acknowledges only complete, decoded results. Configs selects compatible releases after testbed validation.

**Tech Stack:** Proxmox Perl API modules, existing overlay packaging, Go provider transport, and existing acceptance tests.

**Spec:** [API reliability design](../specs/2026-10-24-api-reliability-design.md)

## Global Constraints

Do not change resource identities or state schemas.
Use isolated Git worktrees and do not revert unrelated changes.
Exclude credentials, command input, and result contents from diagnostics.
Use real dependencies for regression tests.
Complete both API corrections before further network reset experiments.
Verify testbed behavior before production deployment.

## Review Focus

Streamed downloads must close explicitly and return their complete content.
Compressed replies must report their original content encoding and correct byte lengths.
Concurrent result reads and acknowledgment must not produce partial results.
Capacity exhaustion must refuse execution before a command starts.
QEMU result consumption during a worker crash must report uncertainty rather than replay a command.

## Task 1: Correct proxy response headers

Files: add the canonical `pve-http-server` patch, update its overlay packaging, and add public API regression coverage in the existing test harness.

- [x] Update the canonical upstream overlay source and regenerate `patches/pve-http-server.patch`.
- [x] Remove backend connection fields and their nominated headers before public response construction.
- [x] Explicitly close connections for streams and responses without valid body framing.
- [x] Verify sequential protected reads on one TLS connection without reconnecting.
- [x] Verify gzip, deflate, streamed downloads, and WebSocket isolation.
- [x] Commit only this correction and its relevant tests.

## Task 2: Retain and acknowledge command results

Files: update canonical LXC and QEMU overlay modules and their generated component patches. Update provider `transport/guest.go`, the request body contract, and relevant public acceptance tests.

Interface: `GET exec-status?pid=<id>` reads a saved result without consuming it. `POST exec-ack` accepts `{ "pid": <id> }` and returns a successful empty result after cleanup. Repeat acknowledgment succeeds. Both operations enforce the existing guest execution privilege. Command starts include `result-retention=acknowledged`; an older server must reject that parameter before execution.

- [ ] Reserve bounded result capacity before command execution.
- [ ] Save completed LXC results and cache completed QEMU results before replying.
- [ ] Implement acknowledgment, expiry, concurrency protection, and capacity release.
- [ ] Decode and validate provider results before acknowledgment. Report acknowledgment failures and return the known result.
- [ ] Verify repeated result retrieval after a lost response, acknowledgment, expiry, capacity, and access checks with real LXC and QEMU dependencies.
- [ ] Commit the server and provider corrections in logical groups.

## Task 3: Integrate and verify releases

- [ ] Review both implementations against the design and inspect their complete diffs.
- [ ] Run existing required checks and the public API regressions on the testbed.
- [ ] Update compatible release selections and coordinate active callers.
- [ ] Deploy the validated corrections and verify installed revisions and behavior separately.
- [ ] Resume the network reset investigation using the retained captures and kernel evidence.
