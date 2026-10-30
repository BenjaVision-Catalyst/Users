# Users API through Connect

Load `connect` / `CatalystUsersConnect.ston` for `BVC-Users-Connect-Core`.
Default Users loading remains Core and Runtime. `tests-connect` adds the optional
qualification fixtures; production uses `CUUsersObjectApplication`.

Configure a local authoritative `#users` service and a Connect `#users` binding.
Enable operations `#(1 2 3 4 5 6 7 8 9 65534)` for both snapshot and live clients; existing
configurations with only 1/2 remain supported. The configured peer principal is
bound to the pinned transport identity. A label is not an account credential.
Connect and Users use the existing configured default transactional worker,
capability checks, routing and published evidence. No alternative worker, store,
management connection or routing system is introduced.

## Live User lifecycle

`CUUser` has a stable, server-assigned identifier and a monotonic state revision.
Legacy and default Users receive their identity lazily during a live transaction.
The temporary `CUUsers AllUsers` store is unchanged; tenant storage remains future
work. Names remain exact, case-sensitive and nonunique; ambiguous lookup refuses.

Swift `CUUsers` and Unreal's per-GameInstance `UCUSubsystem` maintain an identity
map within the selected transport scope. Confirmed creation adopts the original
native object. Lookup of the same identifier returns that instance while it is
retained. Identity is never transferred across authority connections. Different
client scopes retain independent replicas of the same persistent User.

```swift
let users = try CUUsers(connect: connectedTransport)
let user = CUUser(name: "Ada")
users.createUser(user) // Fabric owns execution; observe the optional operation if needed.
// user.replica reports creating/live/uncertain/conflict and the committed identity/revision.
user.name = "Ada Lovelace" // Pending edit; submitted automatically after confirmation.
```

```cpp
auto* Users = GameInstance->GetSubsystem<UCUSubsystem>();
Users->UseConnection(TEXT("Users")); // Existing caller-configured Connect connection.
auto* User = NewObject<UCUUser>(GameInstance); // Retain through UPROPERTY in the host.
User->SetUserName(TEXT("Ada"));
Users->CreateUser(User); // Optional UCUUserOperation; subscribe to OnError when needed.
```

The Fabric negotiates installed Magritte descriptions automatically for live calls.
Swift uses our Magritte Swift port, native accessors and ObservableObject;
Unreal uses our C++ port, native accessors and UObject change/error events.
Server-owned fields are read-only in live descriptions. The transfer constructs
inert installed values before applying a state; peer bytes never choose code,
classes, selectors or destinations. UI generation itself is future work.

Configure the Connect endpoint with `nativeProtocolVersion: 2` and the matching
ABI2 library. ABI1 remains available for existing immutable native owners; the
Users notification operation requires the version 2 subscription path.

The authority publishes full-state changes over the connection’s server-initiated
reliable QUIC notification stream. Operation 8 is a one-time native subscription
setup; it returns `subscribed` and grants a session-scoped target for subsequent
notifications. Operations 7/9 add/remove watched identities. Ordinary RPC to
operation 8 is refused. There are no receive/renewal or per-event acknowledgment
RPCs. Latest state is coalesced by User identity until native publication accepts
a byte copy; QUIC then handles reliable delivery and flow control. A later revision
is never removed by acceptance of an earlier one. This does not retain event history.

Live create/update bindings select one Users result completion for both the
response and feed publication. The WorkUnit arms that completion through its bound
Users capability before mutation. After Runtime verifies successful finalization
and, in GemStone, confirmed outer commit and completion recording, the same callback
validates/encodes the result, copies its state into the existing bounded feeds and
completes the response. No separate publication WorkUnit executes on this path.
Feed snapshots share no mutable text with the mutation result. Callback errors close
feeds for recovery and never replay a committed mutation.

Callers without the Users publication completion retain the coalesced reread path:
the service stages identities and routes a transactional publication WorkUnit.
Its completion publishes reread state only after verified finalization. A direct
completion does not drain unrelated staged identities. Probes, reads, recovery,
legacy snapshot calls and subscription setup retain their existing completions.
Native I/O still runs only on Connect's original owner. Persistent publishers use
the existing progress schedule and bounded drive budgets. Slow consumers retain
bounded state without blocking the independent RPC stream.

`CUUsersConfiguration` adds maximumFeeds (default16), maximumUsersPerFeed (256),
and feedLeaseMillis (60000) for unclaimed feeds. Active publishers do not expire
or send lease-renewal traffic. Configuration validation
bounds these, and existing effective-copy/reconciliation applies changes. A service
reconfiguration closes old feeds; clients resubscribe and resnapshot. Existing
plain CRServiceConfiguration Users deployments retain these defaults. Feed state
is activation-local, closes on native target revocation/disconnect or service scope
invalidation, and is cleared on stop. It never
enters the persistent Users model or durable work queue.

Notifications follow mutations through the configured Users API. Direct repository
writes outside that API, deletion notifications and cross-authority change capture
remain future work. The existing default single-destination route is retained;
GemStone qualification colocates Connect and Users on the configured default worker,
as required by the existing activation-local reply path.

Client capacity defaults to64 retained objects (maximum256). The existing
refreshInterval policy now controls local edit/recovery checks, with a one-second
default and 20ms minimum; it does not schedule remote reads. Disable automaticRefresh
for explicit `synchronizeNow` / `RefreshLiveUsers` control. Policy changes apply
live. Swift APIs sharing a ConnectClient share policy/cache. The host owns its
connection/reconnect and retains observed User objects. Reconnect obtains fresh
agreements and subscription snapshots before receiving further changes. Unknown
creation receipts are checked once per connection or explicit synchronization,
without automatically repeating creation.

Edits retain their base revision. A matching revision permits an update; a conflict
returns current state without overwriting the draft. `resolveConflict(keepLocal:)`
/ `ResolveConflict` explicitly accepts remote state or rebases the draft for a
later update. Edits made during creation or an in-flight update remain pending.
An uncertain admitted update is never automatically replayed: reading a snapshot
does not prove whether that write ran. Explicit resolution is required.

Creation has a stable operation key. The authority stores its receipt on the User
in the same transaction as insertion, scoped to the verified creator peer and
original name. Duplicate keys cannot create another User; a reused key with a
different original name refuses. On reconnect the Fabric renegotiates and asks for
the receipt, adopting the original object after confirmation and preserving newer
edits. A missing receipt means unknown and does not authorize recreation. Receipts
last for the User's lifetime; deletion recovery and general operation journals are
not provided. The original one-shot operation remains terminal after an unknown
result; subsequent recovery is visible on the User.

GemStone results, including recovery, use Runtime's existing afterFinalization and
afterCommit completion. No successful response precedes successful outer commit
and completion recording. Rollback or transport loss cannot manufacture success.
Local admission is not durable success. Default error reporting is provided;
applications may install `onError` / `OnFabricError` or per-object observers.

Updates currently require the verified peer that created the User. Reads use the
configured Users capability. Default/legacy Users without a creator are not remotely
editable through these operations. This is an initial peer-level permission rule,
not account/tenant authorization or a production-complete security model.

## Protocol and compatibility

Operations 3/4/5/6 are live create/read/update/recover; 7/9 watch/unwatch identities,
and 8 establishes the native notification subscription. Their installed request
and state descriptions use the additive state-v2 profile. Actual server push uses
ABI2 and ALPN `catalyst-connect/2`, with reliable server-initiated unidirectional
notifications alongside the existing RPC stream. The 4080-byte payload bound is
unchanged; no CapTP, Cap'n Proto or DDS runtime is required. See Connect's
`conformance/object-messaging.md` for manifests.
GT is also an authoritative server using its existing in-memory execution strategy.
Users bindings explicitly opt in to volatile finalization; ordinary transactional
completions remain denied that option. GemStone retains its commit/evidence checks.
GT does not claim database persistence or rollback: existing Runtime memory semantics
on failure remain unchanged. No private GT management connection is introduced.

The profile supports bounded scalar fields, not graph/4, relations, distributed
reference collection or remote code installation.

Legacy operations 1/2 retain their original two-field CUUser schema and fresh-value
semantics. Swift exposes `prepare`, `createUserSnapshot` and `getUserSnapshot`;
Unreal exposes `Prepare`, `CreateUserSnapshot` and `GetUserSnapshot` with
`FCUUserSnapshot` (`FCUUser` remains a C++ alias). Legacy Blueprint nodes use the
Snapshot names. Explicit legacy preparation is required after reconnect.
GT's existing `CUUsersClient` remains a snapshot client for this first live slice.

## Native qualification

Build Connect Swift's combined Apple package using `build-apple.py --users`, and
stage/build Foundation, Connect and Users in an isolated UE5.8 host. Load verified
GT-owned common `tests-connect` source in GemStone. Run:

```sh
python3 scripts/qualify-platform-users.py \
  --project /path/to/bvc-project --deployment development-stone \
  --bvc /path/to/bvc --library /path/to/immutable/libcatalyst_connect.dylib \
  --apple-package /path/to/ApplePackage --swift-repo /path/to/CatalystConnectSwift \
  --users-swift /path/to/CatalystUsersSwift --engine /path/to/UE_5.8 \
  --ue-project /path/to/ConnectHost.uproject --output /path/to/new-results
```

The controller owns one disposable configured Runtime under CCNativeMcpLease.
It checks no result/visibility before commit in independent Gems, exact final
store contents, rollback absence, adoption, caching, automatic refresh, conflicts
and lost-reply recovery. Cleanup removes only owned Users/Runtime, restores the
gate and preserves the existing development worker processes. The controller
reads the released/restored MCP gate outside GT before joining. No GT rebuild,
source installation or Connect performance-harness modification occurs.

Earlier snapshot qualifications remain recorded in
[creation evidence](../conformance/platform-create-user-2026-10-29.json) and
[lookup evidence](../conformance/platform-get-user-2026-10-29.json).
Direct Rowan loading and physical iOS hardware execution remain unqualified.

See [live User qualification](../conformance/live-users-2026-10-29.json) for the
three-platform run, native persistence checks, source verification and build scope.

Publication commit evidence now follows successful live mutation samples and is
labeled `publicationCommitEvidenceSource: verifiedMutationResultFinalization`.
`committedMutationSamples` is the explicit count. Existing report-field aliases
retain that count for older evidence consumers; they are not counts of delivered
notifications. Actual push, held-commit and rollback assertions remain in the native
clients and independent-session checks.

For the dedicated push suite, add `--push-only`; use `--authority gt` to run the
same native clients against a configured GT authority. GT's owner creates/stops
its Runtime inside CCNativeMcpLease. GemStone's controller owns its managed Runtime.
Both wait outside GT for the released/restored gate before joining. The suite checks
held-update delivery, conflicts, reconnect resnapshot and resumed push, zero reads during idle windows and bounded
explicit/readiness reads, and cleanup. GemStone additionally verifies
rollback suppression and independent-Gem visibility before/after commit.

See [QUIC server-push qualification](../conformance/quic-server-push-2026-10-29.json)
for both authorities, idle-window measurements and commit/rollback checks. The
earlier [held-receive qualification](../conformance/pushed-users-2026-10-29.json)
records the superseded transport mechanism.

## Shared User fan-out qualification

The finite many-client driver uses the same configured authority, default worker,
Users route and commit/finalization boundary. Build the combined Apple package with
the current Users Swift tests, then run each authority separately:

```sh
python3 scripts/qualify-user-fanout.py \
  --project /path/to/bvc-project --deployment development-stone \
  --bvc /path/to/bvc --library /path/to/immutable/libcatalyst_connect.dylib \
  --apple-package /path/to/ApplePackage --authority gemstone \
  --clients 1 8 32 60 --output /path/to/new-results
```

Use `--authority gt` for GT. Each profile watches the same three Users and applies
405 confirmed writes, including two continuous bursts of 192 writes. Names include
800 padding bytes, giving approximately 1 KiB states. The writer waits for each
reply; this is a closed-loop workload. Independent XCTest processes keep each
client shard below the native sixteen-owner limit. The listener and Users feed
limits are configured to 64; the default Users feed limit remains 16.

One consumer pauses at eight observers and two pause at thirty-two and sixty.
Their actual bounded notification streams exhaust four native notification
credits. Healthy clients must converge while those streams are paused; ordinary
RPC on a stalled connection must progress. One paused consumer later drains its
stream, while the other reconnects. A quarter of healthy clients also disconnect
during writes, resnapshot, retain their cached CUUser instances and receive further
pushes. Request counters must remain unchanged during bursts and the final idle
window, apart from explicit probes and reconnect setup.

The opt-in application fixture samples existing native counters and bounded feed
state from Connect's owner hook every 500 ms. It charges diagnostic calls to the
existing drive budget and writes immutable numbered evidence files. It does not
change live persistent metrics. GemStone final states and retained publication
commit samples are checked in an independent session. The controller owns startup,
clients and ordinary stop/remove through the existing MCP lease; unsuccessful runs
and their cleanup evidence remain available. The original recovered fixture is
retained unchanged.

The local macOS qualification on 2026-10-29 used debug Swift XCTest clients, the
running GT image/native GemStone, and the release native transport. It measured
these delivered burst-state latencies. Setup, offline resnapshot and final
verification are excluded:

| Observers | GT p99 | GemStone p99 |
| ---: | ---: | ---: |
| 1 | 71 ms | 93 ms |
| 8 | 146 ms | 114 ms |
| 32 | 821 ms | 448 ms |
| 60 | 2609 ms | 3909 ms |

All final states converged. Feed pending state stayed within three identities;
slow native claims stayed within four notification credits. At sixty observers,
about 25% of intermediate burst revisions reached healthy replicas through
latest-state coalescing. These latency percentiles describe delivered revisions,
so they must be read alongside that fraction. OS RSS samples are retained per
process; they include VM/shared mappings and do not establish a long-duration
leak bound. Current 32-call/4096-byte drive budgets were retained.

Concurrent startup exposed refused local native opens being treated as invalid
Swift configuration. Connect Swift now retries only unadmitted opens within the
existing connection timeout, with close/cancellation ownership guards. Accepted
application requests are never replayed. Its read-only `nativeStatistics()` exposes
the existing counters used to verify slow-client credit exhaustion.

See [fan-out evidence](../conformance/user-server-push-fanout-2026-10-29.json) for
rates, latency distributions, coalescing, reconnects, RSS, source verification and
preserved unsuccessful attempts. This is a local Swift/macOS curve under controlled
disconnects, with the current single-listener ceiling of 64 connections. It is not
a maximum-throughput or production-SLO qualification.

Follow-up per-client analysis found uneven service: some healthy observers
received all 384 burst revisions while others received six. Final convergence
therefore does not establish bounded freshness during continuous writes. The
[cost investigation](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Connect/evidence/user-server-push-cost-investigation-2026-10-29.json)
records repeated description/encoding work, the cursor/budget problem, isolated
codec profiles and the proposed fix. No optimization is implemented by that report.

The subsequent scaling change shares a validated encoded publication across feeds
for each finalized snapshot, schema, authorized view and authority epoch. User
snapshots detach text from stored Users; acknowledgement uses copied identity and
revision metadata. Existing coalescing, commit completion and lifecycle checks
remain in charge. The optional Connect adapter owns the bounded cache; Users Core
and Runtime do not acquire a transport dependency.

Connect now resumes with the next unserved observer when a drive budget ends and
uses the existing Runtime progress schedule to drain accepted work. An entirely
Busy pass waits for the normal retry. Configuration exposes `driveCallLimit`
(128), `driveByteLimit` (65536), `driveTimeLimitMillis` (5) and
`publicationCacheCapacity` (128) through the normal Magritte codec and reconciliation.

With the same debug-client serial workload at 60 observers, delivered-state burst
p99 fell from 2609 to 92 ms for GT and from 3909 to 130 ms for GemStone. All 58
healthy observers received all 384 burst revisions on both authorities. The
isolated 60-recipient publication-cost example retained full validation and reduced
3000 encodes to 50, measuring approximately 49x lower time in GT and 48x in GemStone.
These local results do not establish a higher connection ceiling or a hard freshness
SLO. GemStone still exhibited occasional multi-second writer/server pauses,
including with a single observer. Per-client delivery gaps and paced-writer
admission lag are retained in the
[scaling evidence](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Connect/evidence/user-server-push-scaling-2026-10-29.json).

`qualify-user-fanout.py --build-configuration release --write-interval-millis 100`
uses optimized clients and a paced ten-update/second admission schedule. The
writer records its scheduled offer time and actual submission time, so a late
reply cannot silently turn that run into a claim of sustained offered throughput.

The [native VSD follow-up](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Connect/evidence/user-server-push-vsd-2026-10-29.md)
reproduced three multi-second writer stalls with native log-sync bursts and no
serving-Gem GC in the recorded contained intervals. It includes actual VSD chart
snapshots, a steady-window comparison, raw data and bounded collection/analysis
scripts. Runtime and durability semantics remain unchanged.

The [WorkUnit/host-flush investigation](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Connect/evidence/user-workunit-commit-mix-2026-10-29.md)
retains a complete durable completion journal and native commit-rate/idle-window
VSD graphs. Transport drive/request work accounts for 74.3% of application
completions; even nontransactional bodies persist completion evidence. The current
Stone stack and exact binary confirm the `HostFsync`/`F_FULLFSYNC` path. This is
measurement, with no production policy or durability changes.

`qualify-user-fanout.py --observe-workunits` optionally adds one bounded read-only
Gem for a GemStone qualification. It starts before the Runtime, reads existing
execution samples without changing their retention, and exits after Runtime stop
before descriptor removal. Gaps or generation changes fail the collection; work
is never replayed. The extra reader issues no commits but has observation overhead.
After `analyze-user-vsd.py`, run `analyze-user-workunits.py --capture CASE --output
mix.json --vsd-analysis CASE/analysis`. Source `user-workunit-vsd-export.tcl` from a
fresh VSD profile for native commit-rate graphs, using the existing capture and
analysis environment variables. The full reproduction and limitations are in the
evidence archive.

The [configuration-only cadence experiment](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Connect/evidence/user-runtime-cadence-2026-10-29.md)
compares five matched 60-observer runs. Existing configuration values of 50 ms
Connect idle and 1000 ms reconciliation/heartbeat reduce combined worker commits
27.5–28.7%, with complete burst coverage and delivered-update p99 about 112 ms
against 99–101 ms baselines. The 100 ms idle case saves little additional work
and falls behind the ten-write/second offer schedule. These are candidate
settings for this native GemStone workload, with no production default changes.

Pass `--connect-idle-millis`, `--reconcile-interval-millis` and
`--heartbeat-interval-millis` to the GemStone fan-out controller to populate the
existing Runtime configuration. It reads back the accepted values after the run.
Omitted flags retain the qualification's previous 20/100/500 ms settings.
`analyze-user-cadence.py` compares completed experiment cases and emits numeric
inputs for `user-cadence-vsd-export.tcl`, which uses native VSD filters and preserves
the exact aligned chart vectors. Full commands, data and timing limitations are
retained with the linked evidence.
