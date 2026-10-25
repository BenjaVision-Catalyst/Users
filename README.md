# Catalyst Users

Catalyst Users is the planned server-side home for identity, accounts, and
personal relationship information in Catalyst applications. If you want these
concerns owned by one service rather than spread across every client, this is
the component to follow. This repository is currently a placeholder; it does
not yet contain an implemented Users service.

## Planned role

- An authoritative Users domain running over Catalyst Runtime.
- Account security, profiles, devices, sessions, and personal controls.
- Permissioned relationship evidence, with user choices kept separate from
  group membership and governance.
- Application-facing operations delivered through Catalyst Connect.

These are design intentions, not shipped features. Authentication, persistence,
network contracts, and production integration have not been delivered here.

## Installation and development

Install the Catalyst development environment through
[BVC](https://github.com/BenjaVisionPro/bvc#install). There is no functional
package from this repository to install yet.

Read the [component design](https://github.com/BenjaVisionPro/catalyst-workspace/blob/main/Users/Catalyst-Users-Design.md)
for the intended scope and remaining integration work. Design documents describe
the direction; they do not establish a released implementation.

## License

This repository is licensed under the [Catalyst Developer License](LICENSE).

Each developer using Catalyst for development needs an active
BenjaVision-Catalyst subscription: **$5 per month, billed annually at $60 per
developer**, including access to the BenjaVision-Catalyst repository. New products,
updates, bug fixes, and recompilation require active developer subscriptions.
Automated build machines do not need separate subscriptions.

Products lawfully built during active subscriptions may continue to be used,
hosted, sold, and distributed indefinitely without runtime royalties. Customers
and operators do not need subscriptions solely to use or distribute those builds.
Commercial and proprietary products are permitted; this license does not require
you to publish your own source code.

Existing license grants and separately licensed third-party material remain
unaffected. See [LICENSE](LICENSE) for the complete terms.
