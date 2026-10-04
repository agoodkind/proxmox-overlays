# Permission reference

## Privileges

Every privilege below belongs to the `root` privilege group. Custom roles can list them. Among the built-in roles, only `Administrator` includes them.

| Privilege | ACL path | Operation |
| --- | --- | --- |
| `VM.Config.Nesting` | `/vms/<vmid>` | Change the `nesting` flag in the `features` option of a container |
| `VM.Config.Keyctl` | `/vms/<vmid>` | Change the `keyctl` flag in the `features` option of a container |
| `VM.Config.Vsock` | `/vms/<vmid>` | Set, delete, or revert the `vsock` option of a VM |
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
