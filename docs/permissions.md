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
| `VM.Guest.Exec` | `/vms/<vmid>` | Run a command as root in a running container |
| `VM.Guest.FileRead` | `/vms/<vmid>` | Read a file as root in a running container |
| `VM.Guest.FileWrite` | `/vms/<vmid>` | Write a file as root in a running container |
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

## ACL paths

| Path | Scope |
| --- | --- |
| `/acme` | Every ACME account and plugin, with propagation |
| `/acme/accounts` | Every ACME account, with propagation |
| `/acme/accounts/<name>` | One ACME account |
| `/acme/plugins` | Every ACME plugin, with propagation |
| `/acme/plugins/<id>` | One ACME plugin |

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

`VM.Guest.Exec` runs any program as root in the container and can read or write any file there. The existing `VM.GuestAgent.*` privileges apply to the QEMU guest agent of a VM and do not authorize these methods.

`exec` returns `pid` at once and runs the command in a task worker that `pvedaemon` detaches with `fork_worker`. The worker survives the end of the `pvedaemon` process that started it and appears in the task list as `lxcexec`. `pid` is a random number, not a process ID, because a process ID can repeat before a caller reads the result.

The worker starts the command with `lxc-attach --clear-env`, the program that `pct exec` starts. `timeout` defaults to 120 seconds and accepts 1 to 3600. `lxc-attach` starts as the leader of a new process group. After the timeout the worker sends `TERM` to that group, then `KILL` after 5 seconds. A command that calls `setsid` leaves the group and keeps running. The `lxcexec` task of a timed-out command ends with the error `command timed out after <n> seconds` after the worker stores the result.

`exec-status` returns `exited: 0` while the command runs. After the command exits, it returns `exited: 1`, `exitcode`, base64 `out-data` and `err-data`, and `out-truncated` or `err-truncated` when an output exceeds 1 MiB, then deletes the stored result. A command that a signal ends returns 128 plus the signal number. A command that exceeded its timeout returns `exitcode` 124 and `timed-out`. A `pid` that is unknown, already read, or started for another container returns an error.

The worker stores the result in `/run/pve/lxc-exec/<vmid>/<pid>`, which only `root` can read (mode 0700). Each `exec` and `exec-status` call, for any container, deletes results that no caller read within one hour. It also deletes a directory without a status file after two hours.

`file-write` writes the decoded `content` to the absolute path `file` with `tee` in the container and replaces an existing file. `file-read` reads the file with `head` and returns base64 `content`. It sets `truncated` when the file exceeds 4 MiB.

`input-data` and `content` accept at most 128 KiB of base64, which is 96 KiB of data. `pve-http-server` rejects a request body above 512 KiB, and form encoding expands a base64 value to at most three times its length.

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

## Tokens

A token with `privsep=1` has a privilege on a path only when both the token and the owning user have it there. A token ACL entry without a matching user ACL entry grants no access.
