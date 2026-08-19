# Locale Selection And Presentation

- Node type: leaf
- Status: Active
- Parent contract: `holdtype.website.localization@1`
- Clauses: `LOCALE.ROUTE`, `LOCALE.SELECT`, `LOCALE.PRESENT`
- Read when: URL language authority, detection/storage, RTL, screenshots, or responsive locale UI is in scope.
- Do not read when: only SEO metadata/artifact publication is in scope.
- Maximum size: 100 physical lines.

- Each route localizes content/actions/status/errors/accessibility. Selector uses
  native language names and ordinary links; works without JavaScript.
- Direct locale URL always wins. Only `/` uses JavaScript: supported explicit
  localStorage choice first, then `navigator.languages`; non-English uses
  immediate route replacement preserving query/fragment. Browser detection is
  not persisted; selector choice may be.
- Unsupported/ambiguous/unavailable falls back silently to English. Regional
  variants may match; Portuguese→`pt-BR`; only Simplified Chinese→`zh-Hans`,
  never silently Traditional.
- Blocked/bad storage does not break links or browser matching. Missing language
  list keeps root English.
- Arabic declares RTL; inherent LTR names/code/commands remain readable.
  Screenshots/app UI stay English and copy states that truthfully.
- Shared English launch artwork uses localized description identifying English
  words. At phone width five honesty cards stack full-width.
