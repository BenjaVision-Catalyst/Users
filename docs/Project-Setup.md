# Catalyst Users Smalltalk project

This repository owns the portable Users domain and Runtime service for GT/Pharo
and GemStone. Swift and Unreal clients live in their separate repositories and
follow GT/GemStone interoperability work. The old README is not the specification
for this implementation.

The workspace [Users design](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Users/Catalyst-Users-Design.md),
[implementation plan](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Users/Catalyst-Users-Implementation-Plan.md),
[security contract](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Users/Catalyst-Users-Security.md),
[relationship model](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Users/Catalyst-Users-Relationship-Model.md)
and [Users/Groups boundary](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Users/Catalyst-Users-Groups-Boundary.md)
define the domain. Their dated statements that GemStone is unavailable and clients
must come first are superseded by the current working GemStone environment and
the GT/GemStone-first development order.

## Packages and dependency direction

| Package | Responsibility |
| --- | --- |
| `BaselineOfCatalystUsers` | Metacello dependency and platform selections. |
| `BVC-Users-Core` | Portable `CUUser` model and the `CUUsers` API. |
| `BVC-Users-Runtime` | `CUUsersService`, its narrow `CUUsersCapability`, `CUCreateUserWorkUnit`, and the abstract `CUUsersWorkUnit` base. |
| `BVC-Users-Tests` | Portable executable examples and test-only capability-binding probes. |

Production defaults load Core and Runtime. The `core` group loads the model and
data API. Tests are opt-in. Runtime's
`runtime-core` group selects its Pharo or GemStone backend. The Users baseline
preserves an already registered Runtime repository rather than changing its
checkout. Circular class references are loaded atomically.

The service uses Runtime's existing service configuration, named placement,
lifecycle and capability resolution. Users work declares its service and required
capabilities. Unrelated WorkUnits cannot acquire Users authority. The capability
exposes `createUser:` with service-activation fencing. Creation
currently adds a regular user to the temporary store; caller authentication and
tenant authority remain to be implemented. The old DevKit `BVCUsers` plugin is
not its superclass.

`CUUser` has a name and an `isSuperUser` flag, which defaults to false. Domain records, Magritte
descriptions, tenant storage and further domain operations will follow these ownership rules. No empty GT/GemStone adapter packages
are introduced before there is actual platform-specific behavior to put in them.
The default production load has no Connect, Groups, UI, Swift, Unreal or test dependency.
The optional `connect` group supplies the described client and post-commit result
composition documented in [Users through Connect](Connect-CreateUser.md).

## Temporary Users API

`CUUsers` is the class-side entry point for user data. `CUUsers allUsers` lazily
creates an `OrderedCollection` held by the `AllUsers` class variable, seeded
with `admin` (the super user) and `unknownUser` (not a super user).
`CUUsers addUser: aUser` stores and returns the user. Repeated access returns the
same collection; subsequent access and package loading do not reset it or add
duplicate defaults. `CUUsers admin` and `CUUsers unknownUser` return the shared
default user objects.

```smalltalk
CUUsers createUser: (CUUser new name: 'Ada'; yourself).
CUUsers allUsers.
```

This shared collection is the temporary store until the tenant model supplies
ownership and storage. In GemStone, callers own the transaction and commit;
the API does not begin or commit transactions itself.

## createUser

The synchronous data API is `CUUsers createUser: aUser`. It stores and returns the
same `CUUser`. It rejects other object types, super-user creation and insertion of
an object already in `AllUsers` with `CUUserCreationError`. Names are labels at this
stage; this increment introduces no username uniqueness or identity policy.
`addUser:` remains the lower-level storage helper.

`CUUsersService>>createUser:` delegates to that data API. Runtime-facing callers
use `CUCreateUserWorkUnit user: aUser`, addressed to the configured Users service.
The configured service must be authoritative; the service checks the live adopted
configuration before mutation. Its inherited contract requires `CUUsersCapability`; the capability is fenced to
the service activation and cannot be reused after stop/restart. No transport
capability or reply construction occurs in the domain handler.

The WorkUnit declares `requiresTransaction = true` and `allowsConflictReplay =
false`. Pharo performs the body in memory. A configured GemStone Runtime uses
its default `CRGemStoneWorker`; transactional deliveries own dequeue, nested body
rollback, acknowledgement and completion evidence in one outer commit. Runtime
configuration and reconciliation create its worker through the normal launcher.
Routing uses existing published named-service handles. Transactionality is a
WorkUnit requirement, not a worker deployment option.

The returned object is an ordinary handler result. Ordinary automatic result completion still rejects transactional WorkUnits.
The optional Connect composition explicitly selects the native post-commit boundary
and returns a described `CUUser` after confirmed commit. The synchronous
`CUUsers` data API does not select a Runtime or network endpoint.

The portable tests cover native result identity, business rejection, capability
binding/expiry, named-service refusal, service authority and transaction declarations.
Their direct capability/context checks do not claim a GemStone commit.

Run the socket-free native qualification against a development stone with the
verified Runtime and Users production packages already loaded:

```sh
python3 scripts/qualify-managed-create-user.py \
  --project /absolute/path/to/bvc-project \
  --deployment <development-stone> \
  --bvc /absolute/path/to/bvc \
  --output /absolute/path/to/new-evidence-directory
```

The runner loads only two data-only test WorkUnits, generates configuration,
creates/starts a unique named Runtime through bvc, and waits for existing
convergence evidence. It routes creation through the published Users service.
A separate Gem verifies committed creation, rollback after insertion followed by
an error, super-user rejection and unrelated-WorkUnit denial. It then removes
service authority through live configuration, checks refusal without replacing
worker Gems, and checks acknowledgement of work bearing an obsolete version.

On success it stops/removes its Runtime and removes only its created user and
fixture root, retaining the original users. Each phase has a JSON report and
Topaz log. A failed phase retains its Runtime and evidence for inspection; it
does not replay work or clean up an unknown outcome. The phase implementation is
`scripts/qualify-create-user.topaz`. Run it only in dedicated sessions with the
runner's environment. See [configured-Runtime evidence](../conformance/managed-create-user-2026-10-29.json).

## Metacello

For production in GT/Pharo or GemStone with Metacello:

```smalltalk
Metacello new
    baseline: 'CatalystUsers';
    repository: 'github://BenjaVision-Catalyst/catalyst-users:main/src';
    load: #('runtime').
```

Use `load: #('tests')` for the common examples and Runtime test support. The `gt`
and `gemstone` groups are platform aliases for `runtime`. GT tooling is not loaded
into GemStone. The tests exercise named execution and capability/lifecycle
refusals without starting network listeners or creating user accounts.

## Rowan

`rowan/specs/CatalystUsersCore.ston` selects the independent `Core` component.
`rowan/specs/CatalystUsers.ston` selects production `Runtime`, including Core.
`rowan/specs/CatalystUsersTests.ston` selects `Tests`, including its Runtime fixture
dependency. In an appropriately provisioned Rowan image:

```smalltalk
(RwLoadSpecificationV2 fromUrl:
    'https://raw.githubusercontent.com/BenjaVision-Catalyst/catalyst-users/main/rowan/specs/CatalystUsers.ston')
    resolve load.
```

The test component has its own complete package/dependency selection so it does
not resolve both production-only and test-inclusive specifications for the same
Runtime project. Runtime retains ownership of its backend and prerequisite
projects. The Rowan project uses `RowanHybrid` Tonel with source under `src`.

Rowan definitions are checked against the upstream specification classes and
component visitor and parsed with STON. The current development stone has no
Rowan installed, so direct Rowan resolution/loading is not execution-qualified.
Native package loading and the same service contracts are qualified separately
through the installed Tonel/Gofer loader.

For the provisioned bvc development stone, `scripts/qualify-gemstone.topaz` loads
the four Users packages, runs their contracts outside a repository transaction,
checks the baseline groups and Rowan references, and compares every exported
definition with the running stone. Supply `BVC_USERS_SOURCE` as an absolute `src`
directory, numeric `BVC_FOUNDATION_SOURCE_VERSION` for the installed Tonel port,
and `BVC_USERS_REPORT` as a fresh JSON output path. Run it with
`bvc topaz <deployment> --script <absolute-script-path>` from the deployment's
project directory. Runtime production and test-support prerequisites must already
be installed. It does not provision stones or replace Runtime/Connect source.

## Persistence requirements carried forward

The design already specifies a stable opaque user ID with lifecycle/security
revisions; separate scoped profiles, provider identities and authenticators;
and distinct device/session, relationship, preference, operation and audit data.
Identity is not an email address or a transport principal label. Groups owns its
rosters and roles; Users owns personal records and disclosure.

GemStone is the authoritative persistent target. Domain state, retained operation
outcomes and required audit must commit in the same Runtime transaction. Provider
subject uniqueness, monotonic security generations and revision checks are real
database invariants. Live workers, service activations, sockets, grants and
callbacks stay outside the persistent domain graph. GT development state cannot
stand in for rollback or multi-Gem proof.

The next design task is the concrete GemStone representation: durable roots,
aggregate ownership, uniqueness/index structures, concurrent creation/update,
and transaction/result-publication boundaries, derived from those documented
invariants. Until that tenant model is implemented, `CUUsers` uses the temporary
shared `AllUsers` collection described above. Tenant partitioning, indexes and a
general storage adapter remain unimplemented.
