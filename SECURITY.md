# Security Policy

## Supported Versions

| Version | Supported |
| --- | --- |
| 0.1.x (alpha) | Yes |
| Versions below 0.1.0 | No |

Because Prism Music is in early alpha, supported versions can move quickly.
Only the latest alpha line should be considered actively maintained for security updates.

## Reporting a Vulnerability

Please do not report security vulnerabilities in public GitHub issues.

Use GitHub private vulnerability reporting for this repository:

- https://github.com/Jeswanth-009/Prism-Music/security/advisories/new

If private reporting is temporarily unavailable, open a minimal public issue titled:

- Security: private contact requested

Do not include exploit details in that public issue.

## What to Include in a Report

Please include as much of the following as possible:

- short summary and security impact
- affected version, commit hash, or branch
- step-by-step reproduction details
- proof of concept or logs (if safe to share)
- suggested remediation (optional)

## Response Targets

Maintainers target the following response windows:

- acknowledgment within 72 hours
- initial triage within 7 days
- remediation plan or mitigation guidance within 14 days

Complex issues may require more time, but status updates should still be provided.

## Disclosure Policy

Prism Music follows coordinated disclosure:

- report privately first
- fix and validate before public disclosure
- publish release notes after remediation
- credit reporters when requested and appropriate

## Scope

In scope:

- source code in this repository
- CI/CD workflows and release pipeline
- Android signing and artifact publishing path
- dependency vulnerabilities with practical impact on shipped builds

Out of scope:

- social engineering attempts
- denial-of-service spam without actionable technical root cause
- issues in third-party services not caused by Prism Music code
- reports without reproducible technical details

## Safe Harbor

Good-faith security research is welcome.
Please avoid data destruction, service disruption, or privacy violations while testing.
