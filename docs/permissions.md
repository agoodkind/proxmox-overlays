# Permission reference

## Privileges

Every privilege below belongs to the `root` privilege group. Custom roles can list them. Among the built-in roles, only `Administrator` includes them.

| Privilege | ACL path | Operation |
| --- | --- | --- |
| `VM.Config.Nesting` | `/vms/<vmid>` | Change the `nesting` flag in the `features` option of a container |
| `VM.Config.Keyctl` | `/vms/<vmid>` | Change the `keyctl` flag in the `features` option of a container |
| `VM.Config.Vsock` | `/vms/<vmid>` | Set, delete, or revert the `vsock` option of a VM |
| `VM.Config.BPFDelegate.Cmd.<Name>` | `/vms/<vmid>` | Add or remove one BPF command in the `bpfdelegate` option of an unprivileged container |
| `VM.Config.BPFDelegate.Map.<Name>` | `/vms/<vmid>` | Add or remove one BPF map type in the `bpfdelegate` option of an unprivileged container |
| `VM.Config.BPFDelegate.Prog.<Name>` | `/vms/<vmid>` | Add or remove one BPF program type in the `bpfdelegate` option of an unprivileged container |
| `VM.Config.BPFDelegate.Attach.<Name>` | `/vms/<vmid>` | Add or remove one BPF attach type in the `bpfdelegate` option of an unprivileged container |
| `VM.Config.HostNIC` | `/vms/<vmid>` | Change a container's host interface options |
| `Sys.HostNIC.Use` | `/hostnic/<ifname>` | Use a host interface in a container |
| `VM.Guest.Exec` | `/vms/<vmid>` | Run a command as root in a running container or through the QEMU guest agent in a running VM |
| `VM.Guest.FileRead` | `/vms/<vmid>` | Read a file as root in a running container or through the QEMU guest agent in a running VM |
| `VM.Guest.FileWrite` | `/vms/<vmid>` | Write a file as root in a running container or through the QEMU guest agent in a running VM |
| `Sys.ACME.Account.Audit` | `/acme/accounts/<name>` | Read one ACME account and see it in the account list |
| `Sys.ACME.Account.Create` | `/acme/accounts/<name>` | Register an ACME account with that name |
| `Sys.ACME.Account.Modify` | `/acme/accounts/<name>` | Update or refresh one ACME account |
| `Sys.ACME.Account.Remove` | `/acme/accounts/<name>` | Deactivate and delete one ACME account |
| `Sys.ACME.Plugin.Audit` | `/acme/plugins/<id>` | Read one plugin without its credentials and see it in the plugin list |
| `Sys.ACME.Plugin.Secret.Audit` | `/acme/plugins/<id>` | Read the `data` option of one plugin, which stores the DNS API credentials |
| `Sys.ACME.Plugin.Create` | `/acme/plugins/<id>` | Add a plugin with that id |
| `Sys.ACME.Plugin.Modify` | `/acme/plugins/<id>` | Change every plugin option except `data` |
| `Sys.ACME.Plugin.Secret.Modify` | `/acme/plugins/<id>` | Set, replace, or delete the `data` option of one plugin |
| `Sys.ACME.Plugin.Remove` | `/acme/plugins/<id>` | Delete one plugin |
| `Sys.ACME.Certificate.Order` | `/nodes/<node>` | Order a node certificate |
| `Sys.ACME.Certificate.Renew` | `/nodes/<node>` | Renew the node certificate |
| `Sys.ACME.Certificate.Revoke` | `/nodes/<node>` | Revoke the node certificate |
| `Sys.ACME.Config.Audit` | `/nodes/<node>` | Read the `acme` and `acmedomain<n>` options of the node config |
| `Sys.ACME.Config.Account.Modify` | `/nodes/<node>` | Set or delete the `acme` option of the node config |
| `Sys.ACME.Config.Domain.Modify` | `/nodes/<node>` | Set an `acmedomain<n>` option of the node config |
| `Sys.ACME.Config.Domain.Remove` | `/nodes/<node>` | Delete an `acmedomain<n>` option of the node config |
| `Sys.KernelModules.Audit` | `/nodes/<node>` | Read the node's persistent kernel module list and loaded status |
| `Sys.KernelModules.Modify` | `/nodes/<node>` | Set the node's persistent kernel module list and load its allowlisted modules |
| `Sys.HostArtifacts.Audit` | `/nodes/<node>` | Read the installed record and the live file state of a host artifact target on the node |
| `Sys.HostArtifacts.Modify` | `/nodes/<node>` | Stage and install a host artifact on the node |
| `Sys.HostSecrets.Modify` | `/nodes/<node>` | Set a secret field of a host artifact target on the node |

## ACL paths

| Path | Scope |
| --- | --- |
| `/acme` | Every ACME account and plugin, with propagation |
| `/acme/accounts` | Every ACME account, with propagation |
| `/acme/accounts/<name>` | One ACME account |
| `/acme/plugins` | Every ACME plugin, with propagation |
| `/acme/plugins/<id>` | One ACME plugin |
| `/hostnic` | Every host interface |
| `/hostnic/<ifname>` | One host interface |

An account name or plugin id starts with a letter and continues with one or more letters, digits, `_`, or `-`. The access control module rejects every other path under `/acme`.

## ACME plugins, certificates, and node options

`Sys.Modify` grants the same operations as before: on `/` for plugins and node options, and on `/nodes/<node>` for certificates. `Sys.Audit` on `/` still reads the whole node config.

A plugin request needs one privilege for each kind of change. A `POST` or `PUT` that sets `data` needs `Sys.ACME.Plugin.Secret.Modify` in addition to `Create` or `Modify`. A `PUT` that changes only `data` needs only `Sys.ACME.Plugin.Secret.Modify`.

A node config request from a user without `Sys.Modify` on `/` may change only `acme` and `acmedomain<n>` options. One other option in the request fails the whole request.

## Container feature flags

`PUT /nodes/{node}/lxc/{vmid}/config` accepts a caller with any `VM.Config` privilege on `/vms/{vmid}`, including `VM.Config.Nesting` and `VM.Config.Keyctl`. Each option then has its own check.

The `features` check compares the stored flags with the requested flags. A missing boolean flag equals `0`. `delete=features` counts as a change of every stored flag.

| Changed flag | Privileged container | Unprivileged container |
| --- | --- | --- |
| `nesting` | `VM.Config.Nesting` | `VM.Config.Nesting` or `VM.Allocate` |
| `keyctl` | `VM.Config.Keyctl` | `VM.Config.Keyctl` |
| Any other flag | `root@pam` only | `root@pam` only |

A request that changes several flags needs the privilege for each changed flag. A flag that keeps its value needs no privilege.

Container creation and restore use the same `features` check with no stored flags. A privileged container still requires `Sys.Modify` on `/` at creation and restore.

## Container BPF delegation

The `bpfdelegate` option applies to unprivileged containers. Each of `cmds`, `maps`, `progs`, and `attachs` accepts names separated by semicolons.

At container startup, the generated `lxc.hook.start-host` hook mounts bpffs at `/sys/fs/bpf` inside the container. The hook converts the configured lists to `delegate_cmds`, `delegate_maps`, `delegate_progs`, and `delegate_attachs` mount options. Proxmox rejects a directly configured `lxc.hook.start-host` entry.

```
bpfdelegate: cmds=prog_load;map_create;btf_load,maps=hash,progs=sched_cls;socket_filter,attachs=tcx_ingress;tcx_egress;cgroup_inet_ingress
```

Use the lowercase Linux v7.0 enum constant without its prefix. Remove `BPF_` from command and attach constants, `BPF_MAP_TYPE_` from map constants, and `BPF_PROG_TYPE_` from program constants. The option rejects `any`, numeric values, `unspec`, duplicate entries, entries from another list, and enum aliases.

| Key | Privilege | Example |
| --- | --- | --- |
| `cmds` | `VM.Config.BPFDelegate.Cmd.<Name>` | `prog_load` needs `VM.Config.BPFDelegate.Cmd.ProgLoad` |
| `maps` | `VM.Config.BPFDelegate.Map.<Name>` | `hash` needs `VM.Config.BPFDelegate.Map.Hash` |
| `progs` | `VM.Config.BPFDelegate.Prog.<Name>` | `sched_cls` needs `VM.Config.BPFDelegate.Prog.SchedCls` |
| `attachs` | `VM.Config.BPFDelegate.Attach.<Name>` | `tcx_ingress` needs `VM.Config.BPFDelegate.Attach.TcxIngress` |

Construct each privilege suffix by converting the option value from snake_case to CamelCase. The container API requires the corresponding privilege for each name added to or removed from `bpfdelegate`. It does not require privileges for unchanged names.

Proxmox rejects `bpfdelegate` for privileged containers. Container startup also rejects a privileged container that already has this option configured.

`PUT /nodes/{node}/lxc/{vmid}/config` accepts a caller with any of these privileges on `/vms/{vmid}`. The patched `PVE::AccessControl` defines the names, and the patched `PVE::LXC::Config` and the API privilege list read the names from it. The container patch depends on the access control patch.

The hook selects the `lxc-pve-overlay-mount` AppArmor profile before calling `move_mount`. `pve-overlay` installs the profile at `/etc/apparmor.d/lxc-pve-overlay-mount`.

## Container guest methods

Each method runs in `pvedaemon` as root on the node that hosts the container. The container must be running. A stopped container returns an error with its VM ID.

| Method | Path | Requirement |
| --- | --- | --- |
| `POST` | `/nodes/{node}/lxc/{vmid}/exec` | `VM.Guest.Exec` on `/vms/{vmid}` |
| `GET` | `/nodes/{node}/lxc/{vmid}/exec-status` | `VM.Guest.Exec` on `/vms/{vmid}` |
| `POST` | `/nodes/{node}/lxc/{vmid}/file-write` | `VM.Guest.FileWrite` on `/vms/{vmid}` |
| `GET` | `/nodes/{node}/lxc/{vmid}/file-read` | `VM.Guest.FileRead` on `/vms/{vmid}` |

`VM.Guest.Exec` runs any program as root in the container and can read or write any file there. `VM.GuestAgent.*` privileges do not authorize these methods.

`exec` returns `pid` at once and runs the command in a task worker that `pvedaemon` detaches with `fork_worker`. The worker survives the end of the `pvedaemon` process that started it and appears in the task list as `lxcexec`. `pid` is a random number, not a process ID, because a process ID can repeat before a caller reads the result.

The worker starts the command with `lxc-attach --clear-env`, the program that `pct exec` starts. `timeout` defaults to 120 seconds and accepts 1 to 3600. `lxc-attach` starts as the leader of a new process group. After the timeout the worker sends `TERM` to that group, then `KILL` after 5 seconds. A command that calls `setsid` leaves the group and keeps running. The `lxcexec` task of a timed-out command ends with the error `command timed out after <n> seconds` after the worker stores the result.

`exec-status` returns `exited: 0` while the command runs. After the command exits, it returns `exited: 1`, `exitcode`, base64 `out-data` and `err-data`, and `out-truncated` or `err-truncated` when an output exceeds 1 MiB, then deletes the stored result. A command that a signal ends returns 128 plus the signal number. A command that exceeded its timeout returns `exitcode` 124 and `timed-out`. A `pid` that is unknown, already read, or started for another container returns an error.

The worker stores the result in `/run/pve/lxc-exec/<vmid>/<pid>`, which only `root` can read (mode 0700). Each `exec` and `exec-status` call, for any container, deletes results that no caller read within one hour. It also deletes a directory without a status file after two hours.

`file-write` writes the decoded `content` to the absolute path `file` with `tee` in the container and replaces an existing file. `file-read` reads the file with `head` and returns base64 `content`. It sets `truncated` when the file exceeds 4 MiB.

`input-data` and `content` accept at most 128 KiB of base64, which is 96 KiB of data. `pve-http-server` rejects a request body above 512 KiB, and form encoding expands a base64 value to at most three times its length.

## VM guest methods

Command execution and file operations use the QEMU guest agent in a running VM. `exec` checks agent availability before starting its worker.

| Method | Path | Requirement |
| --- | --- | --- |
| `POST` | `/nodes/{node}/qemu/{vmid}/exec` | `VM.Guest.Exec` on `/vms/{vmid}` |
| `GET` | `/nodes/{node}/qemu/{vmid}/exec-status` | `VM.Guest.Exec` on `/vms/{vmid}` |
| `POST` | `/nodes/{node}/qemu/{vmid}/file-write` | `VM.Guest.FileWrite` on `/vms/{vmid}` |
| `GET` | `/nodes/{node}/qemu/{vmid}/file-read` | `VM.Guest.FileRead` on `/vms/{vmid}` |

`exec` returns a random `pid`, not a process ID, immediately and starts a `qmexec` task worker through `fork_worker`. `command` lists the program and arguments; base64 `input-data` supplies standard input.

`timeout` defaults to 120 seconds and accepts 1 to 3600. On timeout, the worker runs `kill` through the agent to send `TERM` to the guest process, then `KILL` after 5 seconds if needed. Child processes continue with qemu-ga 10.0. The task reports `command timed out after <n> seconds` after storing the result.

The `qmexec` worker retries the same `guest-exec` or `guest-exec-status` call at intervals of 0.05 to 1 second while the guest filesystems are frozen during a snapshot or backup; the command timeout counts from worker startup and includes this wait; an already started command continues without restarting while `exec-status` returns `exited: 0`. `exec-status` returns `exitcode` 124 with `timed-out` and empty output for a started command when the agent rejects calls until the timeout; the worker cannot run `kill` through the disabled agent to stop a guest process that is still running; `exec-status` returns an error with the agent message if the command never started.

`exec-status` returns `exited: 0` until the result is ready. A successful completed read returns `exited: 1`, `exitcode`, base64 `out-data` and `err-data`, and `out-truncated` or `err-truncated` for output exceeding 1 MiB. The read deletes the result. Signals produce 128 plus the signal number; timeouts produce `exitcode` 124 and `timed-out`. A `pid` without a stored result for the requested VM returns an error.

The worker stores results in `/run/pve/qemu-exec/<vmid>/<pid>` with directory mode 0700. Each `exec` and `exec-status` call deletes unread results after one hour and directories without a status file after two hours.

`file` must be an absolute path without NUL bytes and at most 4096 characters. `file-write` replaces the file through the agent. `file-read` returns base64 `content` and sets `truncated` above 4 MiB. Both methods call `file-close` after file operations. `input-data` and `content` accept at most 128 KiB of base64, or 96 KiB of data.

## VM vsock option

`vsock` is a boolean VM option with default `0`. With `vsock: 1`, the QEMU command has `-device vhost-vsock-pci,id=vsock0,guest-cid=<vmid>,bus=pci.1,addr=0x1f`.

| Operation | Requirement |
| --- | --- |
| Set, delete, or revert `vsock` through `POST` or `PUT /nodes/{node}/qemu/{vmid}/config` | `VM.Config.Vsock` on `/vms/{vmid}` |
| Create or restore a VM with `vsock` | `VM.Config.Vsock` on `/vms/{vmid}` in addition to the stock creation privileges |
| Clone a VM with `vsock: 1` | Stock clone privileges. The clone copies the option. |
| Set `args` | `root@pam` only, unchanged |

`VM.Config.Options` and `VM.Config.HWType` do not authorize a `vsock` change. A change on a running VM stays pending until the next cold start.

## ACME account methods

| Method | Path | Requirement |
| --- | --- | --- |
| `GET` | `/cluster/acme/account` | Any authenticated user. The result lists only accounts where the caller has `Sys.ACME.Account.Audit`. |
| `POST` | `/cluster/acme/account` | `Sys.ACME.Account.Create` on `/acme/accounts/<name>`. A request without `name` uses `default`. |
| `GET` | `/cluster/acme/account/{name}` | `Sys.ACME.Account.Audit` on `/acme/accounts/{name}` |
| `PUT` | `/cluster/acme/account/{name}` | `Sys.ACME.Account.Modify` on `/acme/accounts/{name}` |
| `DELETE` | `/cluster/acme/account/{name}` | `Sys.ACME.Account.Remove` on `/acme/accounts/{name}` |

`root@pam` passes every check. An account privilege grants no plugin, certificate, or node option operation.

## Kernel module methods

| Method | Path | Requirement |
| --- | --- | --- |
| `GET` | `/nodes/{node}/kernel-modules` | `Sys.KernelModules.Audit` on `/nodes/{node}` |
| `PUT` | `/nodes/{node}/kernel-modules` | `Sys.KernelModules.Modify` on `/nodes/{node}` |

`GET` runs in `pveproxy`. The `modules` field returns names from `/etc/modules-load.d/pve-overlay.conf` in file order. The `loaded` field contains one flag per name. Each flag is `1` when `/sys/module/<name>` exists and `0` otherwise.

The OpenTofu overlay module in `agoodkind/configs` writes each host's `/etc/pve-overlay/kernel-modules.allow` with one name per line. A missing allowlist file permits no names. The API cannot change the allowlist.

`PUT` runs as root in `pvedaemon`. The method accepts a `modules` array, including an empty array. Each name must satisfy all these conditions:

- The name matches `^[a-z0-9_]+$`.
- The allowlist includes the name.
- `modinfo -n` succeeds for the running kernel.
- `modinfo -n` does not print `(builtin)`.

`PUT` rejects the whole request before writing if any condition fails. The error identifies the name and failed condition.

`PUT` removes duplicate names, then runs `/sbin/modprobe -- <name>` for each accepted name in request order. `PUT` writes the accepted names to the persistent module file, one per line, only after every command exits 0. A `modprobe` failure stops the request with an error containing the module name and standard error. The persistent file retains its pre-request content. Modules loaded before the failure remain loaded. A successful request returns the `GET` result. `PUT` never unloads a module. A failed `modinfo -n` check rejects the request with the existing condition message plus any nonempty standard error.

At boot, `systemd-modules-load.service` reads `/etc/modules-load.d` before `pve-guests.service` starts guests.

## Host artifact methods

| Method | Path | Requirement |
| --- | --- | --- |
| `POST` | `/nodes/{node}/host-artifacts/{target}/stage` | `Sys.HostArtifacts.Modify` on `/nodes/{node}` |
| `POST` | `/nodes/{node}/host-artifacts/{target}` | `Sys.HostArtifacts.Modify` on `/nodes/{node}` |
| `GET` | `/nodes/{node}/host-artifacts/{target}` | `Sys.HostArtifacts.Audit` on `/nodes/{node}` |
| `PUT` | `/nodes/{node}/host-artifacts/{target}/secrets/{field}` | `Sys.HostSecrets.Modify` on `/nodes/{node}` |

Each method runs as root in `pvedaemon` on `{node}`. `{target}` is the lowercase hexadecimal SHA-256 of the UTF-8 bytes of a workspace selector. The installer accepts every selector that `validateWorkspaceSelector` in configsctl accepts, including nested selectors and selectors with underscores.

### Host policy

The OpenTofu overlay module in `agoodkind/configs` writes the policy files over root SSH. The API cannot change them. A request reads only the policy file of its target, and the install method also reads the trusted root. A request fails with the path when a required file does not exist. An invalid policy file of another target does not change the result.

The installer relies on valid policy files and does not compare one target policy with another. Policy provisioning must reject two policies of one host that both list the same path in `directories[]`, even when their mode, owner, and group match. Policy provisioning must also reject a path that one policy lists in `directories[]` and another policy of the host lists in `parent_directories[]`. A directory that several targets use belongs to the host owner, and each of those targets lists it in `parent_directories[]`. Task 4 in `agoodkind/configs` implements these checks.

Host files:

| Path | Content |
| --- | --- |
| `/etc/pve-overlay/host-artifacts/targets/<target>.json` | Policy of one target |
| `/etc/pve-overlay/host-artifacts/trusted_root.jsonl` | Output of `gh attestation trusted-root --hostname github.com` |
| `/var/lib/pve-overlay/host-artifacts/<target>/stages/<stage>` | Staged bytes, with `<stage>.json` for the user, kind, and creation time |
| `/var/lib/pve-overlay/host-artifacts/<target>/journal.json` | Journal of an incomplete file transaction |
| `/var/lib/pve-overlay/host-artifacts/<target>/installed.json` | Installed record |
| `/var/lib/pve-overlay/host-artifacts/<target>/secrets.json` | Secret record: version, SHA-256 of the storage file content, and outstanding consumer restarts of each field |
| `/run/lock/pve-overlay-host-artifact-<target>.lck` | Lock file of the target |

The policy file and each directory above it must belong to root, must not be writable by the group or other users, and must not be a symbolic link. The same rule applies to the trusted root.

Policy fields:

| Field | Value |
| --- | --- |
| `workspace` | Exact workspace selector. Its SHA-256 must equal `<target>`. |
| `node` | Proxmox node name. It must equal the local node name. |
| `environment` | Environment name, such as `testbed` |
| `configuration.repository` | Repository that built the archive, such as `agoodkind/configs` |
| `configuration.workflow_uri` | Complete workflow identity, such as `https://github.com/agoodkind/configs/.github/workflows/ci.yml@refs/heads/main` |
| `configuration.source_ref` | Source ref of the build, such as `refs/heads/main` |
| `configuration.signer_digest` | Optional 40-character signer revision |
| `configuration.max_archive_bytes` | Largest archive stage |
| `configuration.max_bundle_bytes` | Largest bundle stage |
| `directories[]` | Each entry has the `path`, `mode`, `owner`, and `group` of a directory that the target owns. An install may create the directory or change its owner and mode. |
| `parent_directories[]` | Optional. Each entry has the `path` of an inspect-only parent directory and may also have all three of `mode`, `owner`, and `group`. An install checks the directory and never creates or changes it. |
| `files[]` | `path`, `mode`, `owner`, and `group` of each file that an archive may write |
| `secret_fields[]` | Optional. `name`, `storage_path`, `mode`, `owner`, `group`, `pattern`, `min_length`, `max_length`, and `consumer_units` of each secret field |

A policy rejects unknown fields. Each path is absolute, does not contain empty, `.`, or `..` components, and is outside `/etc/pve-overlay` and `/var/lib/pve-overlay`. A mode has the form `0` followed by three octal digits.

### Stage method

The request has `kind` (`archive` or `bundle`), `offset`, `data`, and `stage`. `data` accepts at most 128 KiB of base64. Offset 0 creates a stage, and the request omits `stage`. Every other offset must equal the current stage length, and the request must include the stage. The response returns `stage`, 32 hexadecimal characters that the host chooses, and `length`.

A stage belongs to the authenticated user, the target, and the kind. A chunk from another user or for another kind fails. A stage cannot exceed `max_archive_bytes` or `max_bundle_bytes`. Each stage call deletes stages of the same target that are older than one hour and that the journal does not list.

### Install method

The request has `release-tag`, `asset`, `sha256`, `source-revision`, `archive-stage`, and `bundle-stage`. The method checks the policy, the node, and both stages, then starts a `hostartifact` task and returns its UPID. The task takes the target lock with a 10-second timeout and runs these steps:

1. The task runs `/usr/bin/gh attestation verify` on the staged archive with `--hostname github.com`, `--repo`, `--cert-identity`, `--source-digest`, `--source-ref`, `--signer-digest` when the policy has `signer_digest`, `--deny-self-hosted-runners`, `--bundle`, `--custom-trusted-root`, and `--format json`. The environment contains only `HOME` and `GH_CONFIG_DIR`, both a new 0700 directory, and `GH_HOST=github.com`.
2. The task requires a subject with the requested `asset` and `sha256` in every verified statement, and compares the SHA-256 of the staged archive with `sha256`.
3. The task restores the files of an incomplete journal.
4. The task checks the archive and the manifest.
5. The task writes the changed files and the installed record.
6. The task deletes both stages.

The install task does not start, stop, restart, or reload a service.

The archive is a gzip POSIX ustar archive with `manifest.json` and one `files/<path without the leading slash>` member for each manifest file. The task rejects the archive before any write in these cases:

- A member is not a regular file, has a link target, or has mode bits outside 0777.
- A member name is absolute or contains a backslash or an empty, `.`, or `..` component.
- A member is missing, extra, or listed twice.
- A member size or SHA-256 differs from the manifest.
- The archive has data after its end marker or after the gzip stream.
- The manifest has an unknown field, a `schema_version` other than 1, or a `repository`, `source_revision`, `workspace`, `node`, or `environment` that differs from the policy, the request, or the local node.
- A manifest file or directory does not equal a policy entry in `path`, `mode`, `owner`, and `group`.
- The owner or group does not exist on the node.
- A parent of a destination is not a directory. A parent that the manifest does not list as an owned directory and the policy does not list as an inspect-only parent does not exist, does not belong to root, or permits the group or other users to write to it.
- An inspect-only parent directory does not exist, or it differs from the `mode`, `owner`, and `group` of its policy entry. When the policy entry does not list these values, the directory does not belong to root or permits the group or other users to write to it.
- A manifest directory is not in `directories[]` or `parent_directories[]` of the policy. The install does not change a manifest directory that the policy lists in `parent_directories[]`, and the installed record does not list it.
- A destination exists and is not a regular file.

The task compares each manifest file with the live file. A file with the same content, size, mode, owner, and group keeps its bytes and its `write_id`. The task writes each other file to a temporary file in the same directory, then renames it over the destination. It deletes each file of the earlier installed record that the manifest omits and that the policy lists. A manifest with an empty `files` list deletes every installed file of the target. An install that matches every live file writes only `installed.json`.

The task writes a journal listing each planned temporary file, backup, and directory before the first change. The task links each existing destination to a backup before it replaces or deletes the destination. When a step fails, the task renames each backup over its destination, deletes each new file that did not exist before, deletes the temporary files, and deletes each directory it created if the directory is empty. The journal lists only owned directories. The task restores the previous owner or mode of an existing owned directory only when the transaction changed that value and the directory still has the value that the transaction set. The task then fails with the original error. When the restore also fails, the error contains both messages. When the task stops before it finishes, the journal remains. The next install of the target restores the files in the same way before it checks the new archive. When the journal is in the committed phase, the restore step instead writes the installed record from the journal and deletes the backups.

### Secret method

The request has `value` and `version`. `{field}` is the `name` of a secret field in the target policy. The method rejects other parameters, a field that the policy does not list, a value with a control character, and a value that does not match the length limits and the anchored `pattern` of the field. Responses, errors, task arguments, and task logs do not contain the value. The method then starts a `hostsecret` task and returns its UPID.

Secret field values:

| Field | Value |
| --- | --- |
| `name` | Field name of uppercase letters, digits, and `_` |
| `storage_path` | File with the line `<name>=<value>`. It is not a policy file or directory, and each field has its own file. |
| `mode`, `owner`, `group` | Metadata of the storage file |
| `pattern` | Regular expression that the whole value must match |
| `min_length`, `max_length` | Length limits of the value, from 1 to 512 |
| `consumer_units` | Service units that read the storage file |

The task takes the target lock with a 10-second timeout and restores an incomplete artifact journal first. A version lower than the recorded version fails. The recorded version with another value fails. When the version and value match the record, the storage file has the recorded content and metadata, and the record does not list an outstanding restart, the task does not change anything.

In every other case, the task records the version before it writes. When the storage file differs in content, mode, owner, or group, the task records a restart for each consumer unit that is running, then writes the file through a temporary file in the same directory and a rename. The task then runs `systemctl restart` for each recorded unit and removes each unit from the record after its restart succeeds. A failed or stopped task leaves the remaining restarts in the record. The next request for the field that passes the version checks runs them.

### Read method

The response has `workspace`, `node`, `environment`, `state`, `installed`, `files`, `observed_sha256`, and `secrets`. `secrets` has one entry for each secret field of the policy with `field`, `configured` (1 when the storage file exists), the recorded `version`, and the `sha256` of the storage file. An entry does not contain the value. `state` is `none` without an installed record, `interrupted` while the journal exists, and `committed` otherwise. `installed` is null without an installed record. Otherwise it has `release_tag`, `asset`, `sha256`, `source_revision`, `manifest_sha256`, `upid`, `user`, and `installed_at`.

`files` has one entry for each file of the installed record. Without a record, it has one entry for each policy file. Each entry has `path` and `present`, and the live `sha256`, `size`, `mode`, `owner`, `group`, `uid`, and `gid` of a present file. With a record, each entry also has `write_id` and `matches`. `matches` is 1 only when the live file has the recorded content, size, mode, owner, and group. `write_id` is the UPID of the task that last wrote the file.

`observed_sha256` is the SHA-256 of the path, presence, SHA-256, size, mode, owner, and group of every listed live file. A missing or changed file changes the value. The read method does not change a file.

## Tokens

A token with `privsep=1` has a privilege on a path only when both the token and the owning user have it there. A token ACL entry without a matching user ACL entry grants no access.
