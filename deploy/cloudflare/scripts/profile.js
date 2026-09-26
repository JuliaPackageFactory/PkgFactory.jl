// Run after building both production images. Works from any working directory.
import { execFileSync, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
const app = process.argv[2];
if (!["web", "mcp"].includes(app)) throw new Error("Usage: node scripts/profile.js web|mcp");
const image = `pkgfactory-${app}:cloudflare`;
const command = JSON.parse(execFileSync("docker", ["image", "inspect", image,
  "--format", "{{json .Config.Cmd}}"], { encoding: "utf8" }));
// Use exactly the shipped Julia runtime flags; replace only its application entrypoint.
if (!command.at(-1).endsWith("/cloudflare-server.jl")) throw new Error("Unexpected image entrypoint");
// Cloudflare may use a different CPU from the build host. Reject an image that
// would have to recompile its packages when only baseline x86-64 is available.
const moduleName = app === "web" ? "PkgFactoryWeb" : "PkgFactoryMCP";
execFileSync("docker", ["run", "--rm", "--memory=1g", "--memory-swap=1g", "--cpus=0.25",
  "--network=none", image, ...command.slice(0, -1), "--cpu-target=generic",
  "--compiled-modules=strict", "-e", `using ${moduleName}; println("Portable Julia cache: OK")`],
  { stdio: "inherit" });
const profile = fileURLToPath(new URL("./", import.meta.url));
const fixtures = fileURLToPath(new URL("../../../test/fixtures", import.meta.url));
const result = spawnSync("docker", ["run", "--rm", "--memory=1g", "--memory-swap=1g", "--cpus=0.25",
  "--network=none", "--mount", `type=bind,source=${profile},target=/profile,readonly`,
  "--mount", `type=bind,source=${fixtures},target=/fixtures,readonly`, image,
  ...command.slice(0, -1), "/profile/profile.jl", app], { stdio: "inherit" });
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
