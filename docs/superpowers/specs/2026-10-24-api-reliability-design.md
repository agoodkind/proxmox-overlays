# Proxmox API connection and result reliability

The API must reuse connections for complete JSON replies and save command results when a reply fails. Complete both corrections before resuming the separate network reset investigation.

## Connection behavior

Remove backend connection headers before the public proxy constructs its response. Parse `Connection` as a comma-separated token list and remove every header that the list identifies. Remove `Connection`, `Keep-Alive`, `Proxy-Connection`, `TE`, `Trailer`, `Transfer-Encoding`, and `Upgrade` from the backend reply.

Forward the original content encoding and use the existing compression settings. Explicitly close connections for streamed downloads and replies without valid body framing. Do not change the separate WebSocket upgrade handler.

## Command results

Make `GET exec-status` repeatable for completed LXC and QEMU commands. Reading a completed result must not delete its saved payload. The provider must decode and validate the complete result before acknowledging receipt.

Add an idempotent `POST exec-ack` operation with a numeric `pid` and the existing guest execution privilege. Acknowledgment deletes the saved payload. Repeating acknowledgment succeeds without starting or stopping a command. An acknowledgment failure must report a cleanup warning and return the decoded command result.

Expire completed results after one hour. Limit saved payload capacity to 256 MiB and result records to 1,024 per host. Reserve capacity before execution and reject new work before starting a command when capacity is unavailable. Release capacity after acknowledgment or expiry. These capacity values are implementation choices for this correction.

Cache completed QEMU guest-agent results before returning them to the caller. A crash between consuming the guest-agent result and saving its copy remains an uncertain outcome. Ordinary commands must not repeat after an uncertain start. Read-only calls may repeat an inspection after a lost start reply. Status recovery must request the same accepted command identifier. This change does not promise execution exactly once across crashes or restarts.

The provider sends `result-retention=acknowledged` with every command start. Both APIs accept that single value. Older APIs reject the unknown parameter before starting a command.

## Verification and rollout

Use real dependencies through the public API. Prove connection reuse with sequential protected read requests on one TLS socket, with client reconnection disabled. Verify compressed replies and complete streamed downloads separately.

For each guest kind, lose a completed-result reply, read the result again, decode it, acknowledge receipt, and repeat acknowledgment. Verify capacity refusal before execution, expiry, access checks, and malformed responses. Do not use fake guest agents or recorded responses.

Deploy compatible server and provider releases together after testbed validation. Old clients do not acknowledge results and can exhaust bounded retention. Coordinate that deployment requirement with active callers. Do not replace resource identities or transfer infrastructure state.

## References

- [HTTP connection-specific headers](https://www.rfc-editor.org/rfc/rfc9110.html#section-7.6.1)
- [QEMU guest command result consumption](https://www.qemu.org/docs/master/interop/qemu-ga-ref.html#command-guest-exec-status)
- [Provider resource reads](https://developer.hashicorp.com/terraform/plugin/framework/resources/read)
