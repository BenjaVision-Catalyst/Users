# Users creation through Connect

The optional `connect` load group adds `BVC-Users-Connect-Core`. Default Users
loading still selects only `BVC-Users-Core` and `BVC-Users-Runtime`.

```smalltalk
Metacello new
    baseline: 'CatalystUsers';
    repository: 'github://BenjaVision-Catalyst/catalyst-users:main/src';
    load: #('connect').
```

`CUUser` supplies its own name/Boolean Magritte descriptions through this optional
package. Connect derives both codecs from those descriptions. No application field
schema, request identifier, networking capability or reply-building code is needed
in the Users handler.

Configure `CCQuicConfiguration` with `CUUsersObjectApplication`, allowed operations
`#(1 65534)`, pinned native peer options and a `#users` service binding. On the
server the binding is local and names the authoritative `#users` service. On the
client it names the expected Runtime and this local Connect service. The expected
Runtime label must match the configured Connect principal; the certificate pin is
the transport trust mapping for that label. A label is not an account credential.

For this first deployment, place Connect and Users on the same configured
application worker, with a separate orchestrator if desired. Runtime creates its
default worker from configuration. Existing publications select the named service;
the native topology attaches the local operational handle only in its owning Gem.
Other Gems keep their existing remote proxies. No published state or router is
replaced. Activation-local callbacks and routing tickets are refused by the
durable queue, so cross-Gem reply delivery is not implied by this arrangement.

After the configured client Connect service is available:

```smalltalk
users := CUUsersClient usingConnectService: connectService.
future := users createUser: (CUUser new name: 'Ada'; yourself).
"After future isFinished, a completed future value is a native CUUser."
```

Startup establishes the immutable description agreement and read-only capability
probe. Calls before binding readiness return `unavailable`. The client-created
object is reconstructed as a native `CUUser` in GemStone. The installed
`CUCreateUserMessageWork` retains the existing Users capability/transaction
contracts and delegates to `CUCreateUserWorkUnit`; the service calls `CUUsers`.
No transport state enters the Users store.

Runtime completion explicitly opts in to both `afterFinalization` and `afterCommit`.
The default native worker retains the result locally until its owned outer commit
returns successfully and completion evidence is recorded. Only then can Connect
encode and publish it. Inner rollback, rejected/uncertain commit, or recording
failure cannot publish success. Callback/encoding failure cannot replay a committed
creation. Portable in-memory execution cannot claim a committed result.

The client receives a new native value with the committed user's current fields;
this temporary model does not yet supply a stable user identifier. Failures after
admission currently return `unknown`, including confirmed rollback at the server.
No automatic retry follows that state. Typed business-error results, durable reply
recovery and tenant/account authorization remain separate work.

## Repeatable native qualification

Load `tests-connect` in GT and the corresponding verified production and common
qualification packages in the development stone. The GT test group includes
Connect's native MCP lease/owner helpers. The native controller does not provision
stones, rebuild GT or install source. It uses the existing immutable native library.

```sh
python3 scripts/qualify-connect-create-user.py \
  --project /absolute/path/to/bvc-project \
  --deployment <development-stone> \
  --bvc /absolute/path/to/bvc \
  --library /absolute/path/to/libcatalyst_connect.dylib \
  --output /absolute/path/to/new-evidence-directory
```

The runner creates a unique configured server Runtime and a configured GT client
Runtime, with one independent GT owner under `CCNativeMcpLease`. It waits outside
GT for the released/restored gate before inspecting/joining. Its explicit server
test application reuses the production Users operation and adds one post-insertion
failure case. The client observes native committed success and no success for that
rollback or super-user rejection. A fresh Gem confirms that only the successful
user persisted. It also verifies rejection of an invalid authority change while a
local binding requires that authority. Successful cleanup removes only its test
Runtime/user/root and positively releases GT native buffers. Failed runs retain
their evidence for inspection.

Rowan equivalents are `CatalystUsersConnect.ston` and
`CatalystUsersConnectTests.ston`; the latter adds common tests without GT scenario
classes. Syntax and dependency selection are checked; direct Rowan loading remains
unqualified in the current stone. See [qualification evidence](../conformance/connect-create-user-2026-10-29.json).
