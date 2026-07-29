# Deployment Runbooks by Version

This directory contains version-specific deployment procedures and known issues.

## Versions

- **[wazuh_4_14_6/](wazuh_4_14_6/)** — Production tested (4.14.6)
  - ✅ Complete runbook with all known gotchas
  - ✅ Verified working with TheHive integration
  - ✅ Blog post EOL detection tested

- **[wazuh_5_0_0/](wazuh_5_0_0/)** — In progress (5.0.0)
  - 📋 Stub runbook (awaiting Phase 2 research)
  - 📋 Installation procedure TBD
  - 📋 Breaking changes to document

- **[upgrade_4_to_5/](upgrade_4_to_5/)** — Planned
  - 🔴 Not yet implemented
  - 🔴 Will document migration path
  - 🔴 Phase 4 deliverable

## Quick Navigation

| Need | Location |
|------|----------|
| Deploy Wazuh 4.14.6 | [wazuh_4_14_6/RUNBOOK.md](wazuh_4_14_6/RUNBOOK.md) |
| Deploy Wazuh 5.0.0 | [wazuh_5_0_0/RUNBOOK.md](wazuh_5_0_0/RUNBOOK.md) |
| Upgrade from 4→5 | upgrade_4_to_5/ (coming Phase 4) |
| Known issues (4.14.6) | [wazuh_4_14_6/known-issues.md](wazuh_4_14_6/known-issues.md) (in progress) |
| Known issues (5.0.0) | wazuh_5_0_0/known-issues.md (coming Phase 2) |

## Status Summary

| Version | Status | Notes |
|---------|--------|-------|
| 4.14.6 | ✅ Production | Full documentation, tested |
| 5.0.0 | 📋 Phase 2 | Research in progress |
| Upgrade Path | 🔴 Phase 4 | Designed, awaiting implementation |

---

See [../README.md](../README.md) for version support matrix.
