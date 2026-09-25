// Test the browser adapter with alternate core defaults, without GitHub or a DOM dependency.
const { readFileSync } = require("node:fs");
const { join } = require("node:path");
const vm = require("node:vm");
const assert = require("node:assert/strict");
const elements = new Map();
const element = (selector) => {
  if (!elements.has(selector)) elements.set(selector, {
    value: "", checked: false, hidden: false, disabled: false, required: false,
    textContent: "", validity: { valid: true },
    classList: { toggle() {}, add() {} },
    addEventListener() {}, replaceChildren() {}, append() {}, setCustomValidity() {},
    reset() {},
  });
  return elements.get(selector);
};
const config = {
  templates: ["minimum", "simple", "all-in-one"],
  package_schema: {
    required: ["owner", "name", "authors"],
    properties: {
      template: { default: "simple" }, visibility: { default: "private" },
      description: { default: "From the core" }, commit_message: { default: "Core message" },
      resume: { default: false },
    },
  },
};
const context = vm.createContext({
  document: { querySelector: element, querySelectorAll: () => [], createElement: () => ({}) },
  fetch: async () => ({ ok: true, json: async () => config }),
  AbortController, setTimeout, clearTimeout, console,
});
vm.runInContext(readFileSync(join(__dirname, "../public/app.js"), "utf8"), context);
(async () => {
  await vm.runInContext("loadConfiguration()", context);
  assert.equal(element("#template").value, "simple");
  assert.equal(element("#visibility").value, "private");
  assert.equal(element("#commit-message").value, "Core message");
  assert.equal(element("#description").required, false);
  assert.equal(element("#authors").required, true);
  element("#package-name").value = "Example.jl";
  element("#authors").value = "Alice, , Bob";
  const payload = vm.runInContext("packagePayload()", context);
  // Parsing collects input; normalization and rejection belong to the core.
  assert.equal(payload.package_name, "Example.jl");
  assert.deepEqual(Array.from(payload.authors), ["Alice", "", "Bob"]);
  element("#visibility").value = "public";
  vm.runInContext("applyPackageDefaults()", context);
  assert.equal(element("#visibility").value, "private");
  console.log("Browser schema defaults and input translation passed");
})().catch((error) => { console.error(error); process.exitCode = 1; });
