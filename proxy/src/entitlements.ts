// Server-side проверка подписки через RevenueCat REST API с кэшем в KV.
// Клиентскому флагу "я Pro" не доверяем.

const PRO_CACHE_TTL = 3600; // подтверждённый Pro кэшируем на час
const FREE_CACHE_TTL = 60; // отрицательный результат — коротко, чтобы Pro открылся сразу после покупки

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

  let resp: Response;
  try {
    resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(rcUserId)}`,
      { headers: { Authorization: `Bearer ${revenueCatSecret}` } },
    );
  } catch {
    // Сеть недоступна — не кэшируем, перепроверим в следующий раз
    return false;
  }

  // 5xx/429/401: RevenueCat недоступен или ошибка — НЕ кэшируем «Free», иначе
  // платящий подписчик залипает на Free до истечения TTL
  if (!resp.ok) return false;

  let pro = false;
  try {
    const data = (await resp.json()) as {
      subscriber?: { entitlements?: Record<string, { expires_date: string | null }> };
    };
    const ent = data.subscriber?.entitlements?.["pro"];
    if (ent) {
      pro = ent.expires_date === null || new Date(ent.expires_date).getTime() > Date.now();
    }
  } catch {
    return false; // нечитаемый ответ — не кэшируем
  }

  await kv.put(cacheKey, pro ? "1" : "0", {
    expirationTtl: pro ? PRO_CACHE_TTL : FREE_CACHE_TTL,
  });
  return pro;
}
