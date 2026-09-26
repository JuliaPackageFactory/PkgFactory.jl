// Estimate in USD, excluding tax and usage above other product allowances.
// Official rates checked 2026-09-26. Allowances are shared across the account.
const hoursPerAppPerDay = Number(process.argv[2] ?? 1);
const activeCpuHoursTotal = Number(process.argv[3] ?? 1);
const instanceType = process.argv[4] ?? "basic";
const sizes = { basic: { memoryGiB: 1, diskGB: 4 }, "standard-1": { memoryGiB: 4, diskGB: 8 } };
const apps = Number(process.argv[5] ?? 2);
if (![hoursPerAppPerDay, activeCpuHoursTotal].every(n => Number.isFinite(n) && n >= 0) ||
    hoursPerAppPerDay > 24 || !Number.isSafeInteger(apps) || apps < 1 || !sizes[instanceType])
  throw new Error("Usage: node scripts/pricing.js HOURS_PER_APP_PER_DAY ACTIVE_VCPU_HOURS_TOTAL [basic|standard-1] [APP_COUNT]");
const runningHours = apps * 30 * hoursPerAppPerDay;
const memory = Math.max(0, runningHours * sizes[instanceType].memoryGiB - 25) * 0.009;
const disk = Math.max(0, runningHours * sizes[instanceType].diskGB - 200) * 0.000252;
const cpu = Math.max(0, activeCpuHoursTotal - 6.25) * 0.072;
// Conservatively assume each Container's 128 MB Durable Object stays active
// throughout its run. The separate short-lived plan store isn't included here.
const durableObjectDuration = Math.max(0, runningHours * 3600 * 0.128 - 400000) * 12.50 / 1000000;
const subtotal = 5 + memory + disk + cpu;
console.log(JSON.stringify({ instanceType, apps, days: 30, hoursPerAppPerDay, activeCpuHoursTotal,
  workers: 5, memory, disk, cpu, baseAndContainerSubtotal: subtotal, durableObjectDuration,
  estimatedTotal: subtotal + durableObjectDuration,
  excludes: "Other Workers/KV/DO/storage/egress/build overages, other account usage, tax, domain costs" }, null, 2));
