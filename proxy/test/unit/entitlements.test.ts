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

  it("treats an active entitlement as pro and caches it", async () => {
    const kv = new MockKV();
    const fetchMock = stubSubscriber({ pro: { expires_date: null } });
    vi.stubGlobal("fetch", fetchMock);

    expect(await isProUser(asKV(kv), RC_USER, SECRET, false, null)).toBe(true);
    expect(kv.store.get(`pro:${RC_USER}`)).toBe("1");

    // Второй вызов идёт из кэша, без запроса к RevenueCat
    expect(await isProUser(asKV(kv), RC_USER, SECRET, false, null)).toBe(true);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("treats an expired entitlement as free", async () => {
    const kv = new MockKV();
    vi.stubGlobal("fetch", stubSubscriber({ pro: { expires_date: "2020-01-01T00:00:00Z" } }));
    expect(await isProUser(asKV(kv), RC_USER, SECRET, false, null)).toBe(false);
    expect(kv.store.get(`pro:${RC_USER}`)).toBe("0");
  });

  it("fails open to free (without caching) when RevenueCat is unreachable", async () => {
    const kv = new MockKV();
    vi.stubGlobal("fetch", vi.fn(async () => { throw new Error("network"); }));
    expect(await isProUser(asKV(kv), RC_USER, SECRET, false, null)).toBe(false);
    expect(kv.store.has(`pro:${RC_USER}`)).toBe(false);
  });
});
