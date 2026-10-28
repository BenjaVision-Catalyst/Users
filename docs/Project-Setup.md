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
| `BVC-Users-Runtime` | `CUUsersService`, its narrow `CUUsersCapability`, and the abstract `CUUsersWorkUnit` base. |
| `BVC-Users-Tests` | Portable executable examples and test-only capability-binding probes. |

Production defaults load Core and Runtime. The `core` group loads only the model. Tests are opt-in. Runtime's
`runtime-core` group selects its Pharo or GemStone backend. The Users baseline
preserves an already registered Runtime repository rather than changing its
checkout. Circular class references are loaded atomically.

The service uses Runtime's existing service configuration, named placement,
lifecycle and capability resolution. Users work declares its service and required
capabilities. Unrelated WorkUnits cannot acquire Users authority. The current
capability has no account operations yet; the project setup is not registration
or authentication. The old DevKit `BVCUsers` plugin is not its superclass.

`CUUser` starts as an Object subclass with no fields. Domain records, Magritte
descriptions, persistence and real domain operations will be added under these ownership rules. No empty GT/GemStone adapter packages
are introduced before there is actual platform-specific behavior to put in them.
Production currently has no Connect, Groups, UI, Swift, Unreal or test dependency.

## Temporary Users API

`CUUsers` is the class-side entry point for user data. `CUUsers allUsers` lazily
creates an `OrderedCollection` held by the `AllUsers` class variable.
`CUUsers addUser: aUser` stores and returns the user. Repeated access returns the
same collection; package loading does not reset it.

```smalltalk
CUUsers addUser: CUUser new.
CUUsers allUsers.
```

This shared collection is the temporary store until the tenant model supplies
ownership and storage. In GemStone, callers own the transaction and commit;
the API does not begin or commit transactions itself.

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
