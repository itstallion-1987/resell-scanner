// Server-side проверка подписки через RevenueCat REST API с кэшем в KV.
// Клиентскому флагу "я Pro" не доверяем.

const CACHE_TTL_SECONDS = 3600;

export async function isProUser(
  kv: KVNamespace,
  rcUserId: string | null,
  revenueCatSecret: string | undefined,
  devMode: boolean,
  debugProHeader: string | null,
): Promise<boolean> {
  if (devMode && debugProHeader === "1") return true;
  if (!rcUserId || !revenueCatSecret) return false;

  const cacheKey = `pro:${rcUserId}`;
  const cached = await kv.get(cacheKey);
  if (cached !== null) return cached === "1";

  let pro = false;
  try {
    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(rcUserId)}`,
      { headers: { Authorization: `Bearer ${revenueCatSecret}` } },
    );
    if (resp.ok) {
      const data = (await resp.json()) as {
        subscriber?: { entitlements?: Record<string, { expires_date: string | null }> };
      };
      const ent = data.subscriber?.entitlements?.["pro"];
      if (ent) {
        pro = ent.expires_date === null || new Date(ent.expires_date).getTime() > Date.now();
      }
    }
  } catch {
    // RevenueCat недоступен — считаем Free; кэш не пишем, чтобы перепроверить скорее
    return false;
  }

  await kv.put(cacheKey, pro ? "1" : "0", { expirationTtl: CACHE_TTL_SECONDS });
  return pro;
}
