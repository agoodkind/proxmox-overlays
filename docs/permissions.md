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

`bpfdelegate` is a property string option of unprivileged containers. The keys `cmds`, `maps`, `progs`, and `attachs` each take a `;` separated list of names. When the container starts, a `lxc.hook.start-host` hook mounts a bpffs at `/sys/fs/bpf` in the container with the matching `delegate_cmds`, `delegate_maps`, `delegate_progs`, or `delegate_attachs` mount option. The overlay generates the hook entry because Proxmox rejects a raw `lxc.hook.start-host` entry.

```
bpfdelegate: cmds=prog_load;map_create;btf_load,maps=hash,progs=sched_cls;socket_filter,attachs=tcx_ingress;tcx_egress;cgroup_inet_ingress
```

A name is the lowercase enum constant of `include/uapi/linux/bpf.h` in Linux v7.0 without its prefix: `BPF_` for commands and attach types, `BPF_MAP_TYPE_` for map types, and `BPF_PROG_TYPE_` for program types. The option rejects `any`, numbers, `unspec`, duplicates, names of another list, and constants that alias another constant. The accepted names are 39 commands, 34 map types, 32 program types, and 59 attach types.

| Key | Privilege | Example |
| --- | --- | --- |
| `cmds` | `VM.Config.BPFDelegate.Cmd.<Name>` | `prog_load` needs `VM.Config.BPFDelegate.Cmd.ProgLoad` |
| `maps` | `VM.Config.BPFDelegate.Map.<Name>` | `hash` needs `VM.Config.BPFDelegate.Map.Hash` |
| `progs` | `VM.Config.BPFDelegate.Prog.<Name>` | `sched_cls` needs `VM.Config.BPFDelegate.Prog.SchedCls` |
| `attachs` | `VM.Config.BPFDelegate.Attach.<Name>` | `tcx_ingress` needs `VM.Config.BPFDelegate.Attach.TcxIngress` |

`<Name>` is the name in CamelCase. Each of the 164 names has its own privilege. A request that sets, changes, or deletes `bpfdelegate` needs the privilege of every name that is in only one of the old and the new value. A name in both values does not require a privilege. Proxmox rejects the option on a privileged container, and a privileged container with the option fails at start.

`PUT /nodes/{node}/lxc/{vmid}/config` accepts a caller with any of these privileges on `/vms/{vmid}`. The patched `PVE::AccessControl` defines the names, and the patched `PVE::LXC::Config` and the API privilege list read the names from it. The container patch depends on the access control patch.

The hook changes to the AppArmor profile `lxc-pve-overlay-mount` before it moves the mount into the container. `pve-overlay` installs that profile as `/etc/apparmor.d/lxc-pve-overlay-mount`.

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
