import { describe, expect, it } from "vitest";
import { checkLimits, recordUsage } from "../../src/limits";
import { MockKV, asKV } from "./mock-kv";

const DEVICE = "device-test-0001";
const today = () => new Date().toISOString().slice(0, 10);

describe("checkLimits", () => {
  it("allows a free user under the limit and reports remaining", async () => {
    const kv = new MockKV();
    kv.store.set(`total:${DEVICE}`, "3");
    const result = await checkLimits(asKV(kv), DEVICE, false, 5, 300);
    expect(result).toEqual({ allowed: true, remainingFree: 2 });
  });

  it("blocks a free user at the total limit", async () => {
    const kv = new MockKV();
    kv.store.set(`total:${DEVICE}`, "5");
    const result = await checkLimits(asKV(kv), DEVICE, false, 5, 300);
    expect(result.allowed).toBe(false);
    expect(result.reason).toBe("free_limit_reached");
  });

  it("lets a pro user bypass the total limit", async () => {
    const kv = new MockKV();
    kv.store.set(`total:${DEVICE}`, "999");
    const result = await checkLimits(asKV(kv), DEVICE, true, 5, 300);
    expect(result).toEqual({ allowed: true, remainingFree: -1 });
  });

  it("applies the daily cap to pro users too", async () => {
    const kv = new MockKV();
    kv.store.set(`day:${DEVICE}:${today()}`, "300");
    const result = await checkLimits(asKV(kv), DEVICE, true, 5, 300);
    expect(result.allowed).toBe(false);
    expect(result.reason).toBe("daily_cap_reached");
  });
});

describe("recordUsage", () => {
  it("increments daily and total counters for free users", async () => {
    const kv = new MockKV();
    await recordUsage(asKV(kv), DEVICE, false);
    await recordUsage(asKV(kv), DEVICE, false);
    expect(kv.store.get(`total:${DEVICE}`)).toBe("2");
    expect(kv.store.get(`day:${DEVICE}:${today()}`)).toBe("2");
  });

  it("does not touch the total counter for pro users", async () => {
    const kv = new MockKV();
    await recordUsage(asKV(kv), DEVICE, true);
    expect(kv.store.has(`total:${DEVICE}`)).toBe(false);
    expect(kv.store.get(`day:${DEVICE}:${today()}`)).toBe("1");
  });
});
