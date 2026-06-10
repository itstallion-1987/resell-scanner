import { afterEach, describe, expect, it, vi } from "vitest";
import { isProUser } from "../../src/entitlements";
import { MockKV, asKV } from "./mock-kv";

const RC_USER = "rc-user-1";
const SECRET = "sk_test";

function stubSubscriber(entitlements: Record<string, { expires_date: string | null }>) {
  return vi.fn(async () =>
    new Response(JSON.stringify({ subscriber: { entitlements } }), { status: 200 }),
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("isProUser", () => {
  it("returns false without an RC user id or secret", async () => {
    const kv = new MockKV();
    expect(await isProUser(asKV(kv), null, SECRET, false, null)).toBe(false);
    expect(await isProUser(asKV(kv), RC_USER, undefined, false, null)).toBe(false);
  });

  it("honours the debug header only in dev mode", async () => {
    const kv = new MockKV();
    expect(await isProUser(asKV(kv), null, undefined, true, "1")).toBe(true);
    expect(await isProUser(asKV(kv), null, undefined, false, "1")).toBe(false);
  });

  it("treats an active entitlement as pro and caches it for an hour", async () => {
    const kv = new MockKV();
    const fetchMock = stubSubscriber({ pro: { expires_date: null } });
    vi.stubGlobal("fetch", fetchMock);

    expect(await isProUser(asKV(kv), RC_USER, SECRET, false, null)).toBe(true);
    expect(kv.store.get(`pro:${RC_USER}`)).toBe("1");
    expect(kv.ttls.get(`pro:${RC_USER}`)).toBe(3600);

    // Второй вызов идёт из кэша, без запроса к RevenueCat
    expect(await isProUser(asKV(kv), RC_USER, SECRET, false, null)).toBe(true);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("caches a negative result only briefly so Pro unlocks soon after purchase", async () => {
    const kv = new MockKV();
    vi.stubGlobal("fetch", stubSubscriber({ pro: { expires_date: "2020-01-01T00:00:00Z" } }));
    expect(await isProUser(asKV(kv), RC_USER, SECRET, false, null)).toBe(false);
    expect(kv.store.get(`pro:${RC_USER}`)).toBe("0");
    expect(kv.ttls.get(`pro:${RC_USER}`)).toBe(60);
  });

  it("does NOT cache Free when RevenueCat returns a non-2xx status (5xx/429/401)", async () => {
    for (const status of [500, 429, 401]) {
      const kv = new MockKV();
      vi.stubGlobal("fetch", vi.fn(async () => new Response("", { status })));
      expect(await isProUser(asKV(kv), RC_USER, SECRET, false, null)).toBe(false);
      expect(kv.store.has(`pro:${RC_USER}`)).toBe(false);
    }
  });

  it("fails open to free (without caching) when RevenueCat is unreachable", async () => {
    const kv = new MockKV();
    vi.stubGlobal("fetch", vi.fn(async () => { throw new Error("network"); }));
    expect(await isProUser(asKV(kv), RC_USER, SECRET, false, null)).toBe(false);
    expect(kv.store.has(`pro:${RC_USER}`)).toBe(false);
  });
});
