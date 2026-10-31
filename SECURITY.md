# Security policy

DailyMoney stores financial records on the user's device. Please do not open a
public GitHub issue for a suspected security problem.

## Reporting a vulnerability

Email **Ashwinkumar.cs27@gmail.com** with:

- the app version from **Settings** (for example `1.3.1 (8)`);
- the Android version and device model;
- clear steps to reproduce;
- what an attacker could do, and what access they need.

Do **not** include real bank details, full account numbers, card numbers, PINs,
one-time passwords, or a real backup file. A minimal reproduction built from
sample data is enough.

## Scope and expectations

- This is a private beta. There is no bug bounty and no guaranteed response
  time; reports are triaged on a best-effort basis.
- Only the latest beta build is supported.
- The app has no backend, no accounts and no network permission. Server-side
  issues are out of scope.
- The optional notification listener and biometric unlock are described in
  [the security overview](doc/maturity/security-and-privacy-overview.md).

## Not a security report

Feature requests, crashes without a security impact, and questions about the
budget calculations should use the normal issue tracker or the app's Help
Centre.
