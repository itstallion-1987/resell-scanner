// Device-лимиты на KV: суммарный лимит Free и дневной потолок для всех.

export interface LimitResult {
  allowed: boolean;
  reason?: "free_limit_reached" | "daily_cap_reached";
  remainingFree: number; // -1 для Pro (безлимит)
}

function todayKey(): string {
  return new Date().toISOString().slice(0, 10); // YYYY-MM-DD
}

export async function checkLimits(
  kv: KVNamespace,
  deviceId: string,
  isPro: boolean,
  freeTotalLimit: number,
  dailyCap: number,
): Promise<LimitResult> {
  const dayKey = `day:${deviceId}:${todayKey()}`;
  const dayCount = parseInt((await kv.get(dayKey)) ?? "0", 10);
  if (dayCount >= dailyCap) {
    return { allowed: false, reason: "daily_cap_reached", remainingFree: 0 };
  }

  if (isPro) {
    return { allowed: true, remainingFree: -1 };
  }

  const totalKey = `total:${deviceId}`;
  const totalCount = parseInt((await kv.get(totalKey)) ?? "0", 10);
  if (totalCount >= freeTotalLimit) {
    return { allowed: false, reason: "free_limit_reached", remainingFree: 0 };
  }
  return { allowed: true, remainingFree: freeTotalLimit - totalCount };
}

// Инкремент после успешной генерации (не списываем попытку при ошибке модели)
export async function recordUsage(kv: KVNamespace, deviceId: string, isPro: boolean): Promise<void> {
  const dayKey = `day:${deviceId}:${todayKey()}`;
  const dayCount = parseInt((await kv.get(dayKey)) ?? "0", 10);
  await kv.put(dayKey, String(dayCount + 1), { expirationTtl: 60 * 60 * 48 });

  if (!isPro) {
    const totalKey = `total:${deviceId}`;
    const totalCount = parseInt((await kv.get(totalKey)) ?? "0", 10);
    await kv.put(totalKey, String(totalCount + 1));
  }
}
