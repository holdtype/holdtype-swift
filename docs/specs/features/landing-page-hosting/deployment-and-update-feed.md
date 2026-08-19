# Landing Deployment And Update Feed

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.website.hosting@1`
- Clauses: `WEBSITE.DIGITALOCEAN`, `WEBSITE.PAGES`, `WEBSITE.DNS`
- Read when: App Platform, GitHub Pages, appcast, publish workflow, domain, or DNS is in scope.
- Do not read when: only page copy or locale selection is in scope.
- Maximum size: 100 physical lines.

- DigitalOcean static component deploys `website/` from configured production
  branch with managed HTTPS/CDN; push auto-deploys landing only. Explicit
  publish syncs committed `.do/app.yaml`, bounded rebuild, and verifies generated locales.
- Routine website pushes never start Pages. Release workflow alone publishes
  new signed appcast + matching release notes; manual Pages maintenance restores
  complete artifact using latest stable Release appcast, never regenerates it.
- Pages deployments are serialized with website/release publication. Appcast
  and every referenced `HoldType-<version>.md` remain together/reachable.
- Stable feed stays `https://holdtype.github.io/holdtype-swift/appcast.xml`.
  Pages drops `holdtype.app` custom domain; github.io feed must not redirect.
- Before DNS, technical hostname passes marker check. Attach domains only then;
  preserve unrelated DNS and replace only prior Pages apex/`www` records using
  DigitalOcean-provided target.
- Public root is apex; `www` redirects. Cutover changes hosting/DNS, not relative
  assets or shipped feed URL.
