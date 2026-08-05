import assert from "node:assert/strict";
import fs from "node:fs";
import vm from "node:vm";

const source = fs.readFileSync(new URL("./script.js", import.meta.url), "utf8");

const locales = [
  { code: "en", browserMatches: ["en"] },
  { code: "de", browserMatches: ["de"] },
  { code: "ru", browserMatches: ["ru"] },
  { code: "zh-Hans", browserMatches: ["zh-hans", "zh-cn", "zh-sg"] },
].map((locale) => ({
  ...locale,
  href: locale.code === "en" ? "/" : `/${locale.code.toLowerCase()}/`,
  nativeName: locale.code,
  dir: "ltr",
}));

function resolveRedirect({
  savedLocale = null,
  browserLanguages = [],
  storageThrows = false,
  isDefaultRoute = true,
  locationHref = "https://holdtype.app/?campaign=summer#faq",
}) {
  const storage = {
    getItem() {
      if (storageThrows) throw new Error("blocked storage");
      return savedLocale;
    },
    setItem() {},
  };
  const localeConfig = {
    currentLocale: isDefaultRoute ? "en" : "ru",
    defaultLocale: "en",
    isDefaultRoute,
    strings: {},
    locales,
  };
  const localeConfigElement = { textContent: JSON.stringify(localeConfig) };
  const document = {
    body: { children: [], classList: { add() {}, remove() {} } },
    documentElement: { classList: { add() {} } },
    hidden: false,
    querySelector(selector) {
      return selector === "#locale-config" ? localeConfigElement : null;
    },
    querySelectorAll() {
      return [];
    },
    addEventListener() {},
  };
  let redirect = null;
  const initialLocation = new URL(locationHref);
  const window = {
    localStorage: storage,
    location: {
      href: initialLocation.href,
      search: initialLocation.search,
      hash: initialLocation.hash,
      replace(destination) {
        redirect = destination;
      },
    },
    matchMedia() {
      return { matches: false, addEventListener() {} };
    },
  };
  const context = vm.createContext({
    document,
    window,
    navigator: {
      languages: browserLanguages,
      language: browserLanguages[0],
    },
    URL,
  });
  new vm.Script(source, { filename: "script.js" }).runInContext(context);
  return redirect;
}

assert.equal(
  resolveRedirect({ savedLocale: "unsupported-value", browserLanguages: ["de-DE"] }),
  "https://holdtype.app/de/?campaign=summer#faq",
  "an invalid stored locale must fall through to browser-language routing",
);
assert.equal(
  resolveRedirect({ savedLocale: "ru", browserLanguages: ["de-DE"] }),
  "https://holdtype.app/ru/?campaign=summer#faq",
  "a supported explicit choice must take precedence and preserve the URL state",
);
assert.equal(
  resolveRedirect({ browserLanguages: ["zh-TW"] }),
  null,
  "Traditional Chinese must not silently route to Simplified Chinese",
);
assert.equal(
  resolveRedirect({ browserLanguages: ["zh-CN"] }),
  "https://holdtype.app/zh-hans/?campaign=summer#faq",
  "Simplified Chinese regional variants must route to zh-Hans",
);
assert.equal(
  resolveRedirect({ browserLanguages: ["de-DE"], storageThrows: true }),
  "https://holdtype.app/de/?campaign=summer#faq",
  "blocked storage must not disable browser-language routing",
);
assert.equal(
  resolveRedirect({ savedLocale: "en", browserLanguages: ["ru-RU"] }),
  null,
  "an explicit English choice must leave the user on the root route",
);
assert.equal(
  resolveRedirect({ savedLocale: "de", browserLanguages: ["ru-RU"], isDefaultRoute: false }),
  null,
  "a direct locale route must never be replaced by a stored or browser preference",
);

console.log("Locale runtime tests passed.");
