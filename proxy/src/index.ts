import Anthropic from "@anthropic-ai/sdk";
import { LISTING_SCHEMA } from "./schema";
import { SYSTEM_PROMPT, buildUserText } from "./prompt";
import { checkLimits, recordUsage, globalCapReached, recordGlobalUsage } from "./limits";
import { isProUser } from "./entitlements";
import { sanitizeDraft } from "./sanitize";

export interface Env {
  ANTHROPIC_API_KEY: string;
  REVENUECAT_SECRET?: string;
  APP_SHARED_SECRET?: string;
  LIMITS: KVNamespace;
  ANALYTICS?: AnalyticsEngineDataset; // опционально: Workers Analytics Engine
  MODEL: string;
  FREE_TOTAL_LIMIT: string;
  DAILY_CAP: string;
  GLOBAL_DAILY_CAP?: string;
  DEV_MODE?: string;
}

const MAX_NOTE_LENGTH = 500;

const ALLOWED_PLATFORMS = new Set(["ebay", "vinted", "poshmark", "depop", "mercari", "generic"]);
const ALLOWED_MEDIA_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
// BCP-47-образный код (включая 3-буквенные "fil", "haw" и сабтеги); язык — поле
// косметическое, поэтому несоответствие НЕ роняет запрос, а просто игнорируется
const LANGUAGE_RE = /^[a-zA-Z]{2,3}([-_][a-zA-Z0-9]{2,8})*$/;
// ~5 МБ на изображение (лимит Anthropic API); base64 длиннее бинарника на ~33%
const MAX_BASE64_LENGTH = 7_000_000;

interface ListingRequest {
  images: { data: string; media_type: string }[];
  platform: string;
  currency?: string;
  note?: string;
  language?: string;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function badRequest(message: string): Response {
  return json({ error: "bad_request", message }, 400);
}

// Лёгкая событийная аналитика воронки (paywall_shown, copy_all и т.п.) без сторонних SDK.
// Лимиты Analytics Engine: index <= 96 байт, blobs суммарно <= 5120 байт — валидируем
// по БАЙТАМ (не UTF-16-символам) и заворачиваем writeDataPoint в try/catch.
const EVENT_NAME_RE = /^[a-z0-9_]{1,40}$/;

async function handleEvent(request: Request, env: Env): Promise<Response> {
  const deviceId = request.headers.get("x-device-id");
  if (!deviceId || deviceId.length < 8 || deviceId.length > 64) {
    return badRequest("Missing or invalid X-Device-ID header");
  }

  let body: { event?: unknown; platform?: unknown; trigger?: unknown };
  try {
    body = (await request.json()) as typeof body;
  } catch {
    return json({ error: "bad_request" }, 400);
  }
  if (typeof body.event !== "string" || !EVENT_NAME_RE.test(body.event)) {
    return json({ error: "bad_request" }, 400);
  }
  const platform = typeof body.platform === "string" && ALLOWED_PLATFORMS.has(body.platform) ? body.platform : "";
  const trigger = typeof body.trigger === "string" ? body.trigger.slice(0, 64) : "";

  try {
    env.ANALYTICS?.writeDataPoint({
      blobs: ["event", body.event, platform, trigger],
      indexes: [body.event],
    });
  } catch {
    // телеметрия не должна ронять запрос
  }
  return json({ ok: true });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const t0 = Date.now();

    if (url.pathname === "/health") {
      return json({ ok: true });
    }

    if (url.pathname === "/v1/event" && request.method === "POST") {
      if (env.APP_SHARED_SECRET && request.headers.get("x-app-token") !== env.APP_SHARED_SECRET) {
        return json({ error: "unauthorized" }, 401);
      }
      return handleEvent(request, env);
    }

    if (url.pathname !== "/v1/listing" || request.method !== "POST") {
      return json({ error: "not_found" }, 404);
    }

    // Минимальная защита от чужого трафика к прокси
    if (env.APP_SHARED_SECRET && request.headers.get("x-app-token") !== env.APP_SHARED_SECRET) {
      return json({ error: "unauthorized" }, 401);
    }

    const deviceId = request.headers.get("x-device-id");
    if (!deviceId || deviceId.length < 8 || deviceId.length > 64) {
      return badRequest("Missing or invalid X-Device-ID header");
    }

    let body: ListingRequest;
    try {
      body = (await request.json()) as ListingRequest;
    } catch {
      return badRequest("Invalid JSON body");
    }

    if (!Array.isArray(body.images) || body.images.length < 1 || body.images.length > 3) {
      return badRequest("images must contain 1-3 photos");
    }
    for (const img of body.images) {
      if (!img?.data || typeof img.data !== "string" || img.data.length > MAX_BASE64_LENGTH) {
        return badRequest("Each image must be base64 data up to ~5MB");
      }
      if (!ALLOWED_MEDIA_TYPES.has(img.media_type)) {
        return badRequest(`media_type must be one of: ${[...ALLOWED_MEDIA_TYPES].join(", ")}`);
      }
    }
    if (body.note !== undefined && (typeof body.note !== "string" || body.note.length > MAX_NOTE_LENGTH * 4)) {
      return badRequest("note must be a string");
    }
    // Невалидный language тихо игнорируем (как platform/currency): поле косметическое,
    // ронять из-за него основной запрос несоразмерно
    const language =
      typeof body.language === "string" && LANGUAGE_RE.test(body.language) ? body.language : undefined;
    const platform = ALLOWED_PLATFORMS.has(body.platform) ? body.platform : "generic";
    const currency = /^[A-Z]{3}$/.test(body.currency ?? "") ? body.currency! : "USD";

    // Глобальный дневной потолок — защита бюджета от ротации device-id (до любой работы)
    const globalCap = parseInt(env.GLOBAL_DAILY_CAP || "5000", 10);
    if (await globalCapReached(env.LIMITS, globalCap)) {
      return json({ error: "service_unavailable", message: "Daily capacity reached, try again later" }, 503);
    }

    // Подписка + лимиты ДО вызова модели
    const isPro = await isProUser(
      env.LIMITS,
      request.headers.get("x-rc-user-id"),
      env.REVENUECAT_SECRET,
      env.DEV_MODE === "1",
      request.headers.get("x-debug-pro"),
    );
    const limits = await checkLimits(
      env.LIMITS,
      deviceId,
      isPro,
      parseInt(env.FREE_TOTAL_LIMIT || "5", 10),
      parseInt(env.DAILY_CAP || "300", 10),
    );
    if (!limits.allowed) {
      // is_pro намеренно не возвращаем в ошибке — чтобы не давать оракул для перебора RC-ID
      return json({ error: limits.reason, remaining_free: 0 }, 402);
    }

    // ОДИН vision-вызов на объявление, до 3 фото внутри
    const client = new Anthropic({
      apiKey: env.ANTHROPIC_API_KEY,
      maxRetries: 1,
      timeout: 45_000,
    });

    const content: Anthropic.ContentBlockParam[] = body.images.map((img) => ({
      type: "image" as const,
      source: {
        type: "base64" as const,
        media_type: img.media_type as "image/jpeg" | "image/png" | "image/webp",
        data: img.data,
      },
    }));
    content.push({
      type: "text",
      text: buildUserText({ platform, currency, note: body.note, language }),
    });

    let message: Anthropic.Message;
    try {
      message = await client.messages.create({
        model: env.MODEL || "claude-sonnet-4-6",
        max_tokens: 2048,
        // Без thinking + effort low: latency-критичный экстрактивный вызов (цель <= 5 c)
        thinking: { type: "disabled" },
        output_config: {
          effort: "low",
          format: { type: "json_schema", schema: LISTING_SCHEMA as unknown as Record<string, unknown> },
        },
        system: [
          // Стабильный системный промпт + кэш; переменные (платформа/валюта/заметка) — в user-сообщении
          { type: "text", text: SYSTEM_PROMPT, cache_control: { type: "ephemeral" } },
        ],
        messages: [{ role: "user", content }],
      });
    } catch (e) {
      if (e instanceof Anthropic.APIError) {
        const retryable = e.status === 429 || e.status >= 500;
        return json(
          { error: retryable ? "model_busy" : "model_error", message: "Generation failed, please retry" },
          retryable ? 503 : 502,
        );
      }
      return json({ error: "model_error", message: "Generation failed, please retry" }, 502);
    }

    const textBlock = message.content.find((b) => b.type === "text");
    if (!textBlock || textBlock.type !== "text") {
      return json({ error: "model_error", message: "Empty model response" }, 502);
    }

    let draft: unknown;
    try {
      draft = JSON.parse(textBlock.text);
    } catch {
      return json({ error: "model_error", message: "Non-JSON model response" }, 502);
    }

    const d = draft as Record<string, unknown>;
    const recognized = d?.recognized === true;

    // Чистим поля от ссылок/контактов, проникших через note или текст на фото
    const cleaned = sanitizeDraft(draft);

    // Free-попытка списывается только при удачном распознавании; глобальный потолок — всегда
    await recordUsage(env.LIMITS, deviceId, isPro, recognized);
    await recordGlobalUsage(env.LIMITS);
    const charged = !isPro && recognized;
    const remaining = limits.remainingFree === -1 ? -1 : Math.max(0, limits.remainingFree - (charged ? 1 : 0));

    env.ANALYTICS?.writeDataPoint({
      blobs: [
        "listing",
        platform,
        recognized ? "1" : "0",
        typeof d?.confidence === "string" ? (d.confidence as string) : "",
        d?.brand ? "1" : "0",
        isPro ? "1" : "0",
      ],
      doubles: [
        Date.now() - t0,
        message.usage.input_tokens,
        message.usage.output_tokens,
        body.images.length,
      ],
      indexes: [platform],
    });

    return json({
      draft: cleaned,
      meta: {
        is_pro: isPro,
        remaining_free: remaining,
        usage: {
          input_tokens: message.usage.input_tokens,
          output_tokens: message.usage.output_tokens,
          cache_read_input_tokens: message.usage.cache_read_input_tokens ?? 0,
        },
      },
    });
  },
};
