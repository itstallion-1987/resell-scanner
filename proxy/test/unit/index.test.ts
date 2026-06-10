import { beforeEach, describe, expect, it, vi } from "vitest";
import { MockKV, asKV } from "./mock-kv";

// Мок SDK до импорта воркера: тесты не ходят в Anthropic API
const createMock = vi.fn();

vi.mock("@anthropic-ai/sdk", () => {
  class APIError extends Error {
    status: number;
    constructor(status: number) {
      super(`api error ${status}`);
      this.status = status;
    }
  }
  class MockAnthropic {
    static APIError = APIError;
    messages = { create: createMock };
    constructor(_opts: unknown) {}
  }
  return { default: MockAnthropic };
});

import worker, { type Env } from "../../src/index";

const DRAFT = {
  recognized: true,
  confidence: "high",
  title: "Levi's 501 Original Fit Jeans Men's 32x32 Dark Wash Denim",
  brand: "Levi's",
};

function modelResponse(text: string = JSON.stringify(DRAFT)) {
  return {
    content: [{ type: "text", text }],
    usage: { input_tokens: 5000, output_tokens: 700, cache_read_input_tokens: 0 },
  };
}

function makeEnv(kv: MockKV, overrides: Partial<Env> = {}): Env {
  return {
    ANTHROPIC_API_KEY: "test-key",
    APP_SHARED_SECRET: "secret",
    LIMITS: asKV(kv),
    MODEL: "claude-sonnet-4-6",
    FREE_TOTAL_LIMIT: "5",
    DAILY_CAP: "300",
    DEV_MODE: "0",
    ...overrides,
  };
}

function makeRequest(options: {
  body?: unknown;
  headers?: Record<string, string>;
  method?: string;
  path?: string;
} = {}): Request {
  const body = options.body ?? {
    images: [{ data: "aGVsbG8=", media_type: "image/jpeg" }],
    platform: "ebay",
    currency: "USD",
  };
  return new Request(`https://worker.test${options.path ?? "/v1/listing"}`, {
    method: options.method ?? "POST",
    headers: {
      "content-type": "application/json",
      "x-app-token": "secret",
      "x-device-id": "device-12345678",
      ...options.headers,
    },
    body: options.method === "GET" ? undefined : JSON.stringify(body),
  });
}

beforeEach(() => {
  createMock.mockReset();
  createMock.mockResolvedValue(modelResponse());
});

describe("routing and auth", () => {
  it("responds to /health", async () => {
    const resp = await worker.fetch(makeRequest({ path: "/health", method: "GET" }), makeEnv(new MockKV()));
    expect(resp.status).toBe(200);
  });

  it("rejects a wrong app token", async () => {
    const resp = await worker.fetch(
      makeRequest({ headers: { "x-app-token": "wrong" } }),
      makeEnv(new MockKV()),
    );
    expect(resp.status).toBe(401);
  });

  it("rejects a missing device id", async () => {
    const req = new Request("https://worker.test/v1/listing", {
      method: "POST",
      headers: { "content-type": "application/json", "x-app-token": "secret" },
      body: JSON.stringify({ images: [{ data: "x", media_type: "image/jpeg" }], platform: "ebay" }),
    });
    const resp = await worker.fetch(req, makeEnv(new MockKV()));
    expect(resp.status).toBe(400);
  });
});

describe("request validation", () => {
  it("rejects zero and more than three images", async () => {
    for (const images of [[], Array(4).fill({ data: "x", media_type: "image/jpeg" })]) {
      const resp = await worker.fetch(
        makeRequest({ body: { images, platform: "ebay" } }),
        makeEnv(new MockKV()),
      );
      expect(resp.status).toBe(400);
    }
    expect(createMock).not.toHaveBeenCalled();
  });

  it("rejects unsupported media types", async () => {
    const resp = await worker.fetch(
      makeRequest({ body: { images: [{ data: "x", media_type: "image/gif" }], platform: "ebay" } }),
      makeEnv(new MockKV()),
    );
    expect(resp.status).toBe(400);
  });

  it("falls back to the generic platform for unknown values", async () => {
    const resp = await worker.fetch(
      makeRequest({ body: { images: [{ data: "x", media_type: "image/jpeg" }], platform: "amazon" } }),
      makeEnv(new MockKV()),
    );
    expect(resp.status).toBe(200);
    const callArgs = createMock.mock.calls[0][0];
    const textBlock = callArgs.messages[0].content.at(-1);
    expect(textBlock.text).toContain("generic");
  });

  it("rejects a non-string note with 400 instead of crashing", async () => {
    const resp = await worker.fetch(
      makeRequest({
        body: { images: [{ data: "x", media_type: "image/jpeg" }], platform: "ebay", note: 123 },
      }),
      makeEnv(new MockKV()),
    );
    expect(resp.status).toBe(400);
    expect(createMock).not.toHaveBeenCalled();
  });

  it("rejects an invalid language code with 400", async () => {
    const resp = await worker.fetch(
      makeRequest({
        body: { images: [{ data: "x", media_type: "image/jpeg" }], platform: "ebay", language: "german!" },
      }),
      makeEnv(new MockKV()),
    );
    expect(resp.status).toBe(400);
    expect(createMock).not.toHaveBeenCalled();
  });

  it("passes a valid language into the model prompt", async () => {
    const resp = await worker.fetch(
      makeRequest({
        body: { images: [{ data: "x", media_type: "image/jpeg" }], platform: "vinted", language: "de" },
      }),
      makeEnv(new MockKV()),
    );
    expect(resp.status).toBe(200);
    const textBlock = createMock.mock.calls[0][0].messages[0].content.at(-1);
    expect(textBlock.text).toContain("German");
  });
});

describe("/v1/event analytics", () => {
  it("accepts a funnel event and 200s", async () => {
    const req = new Request("https://worker.test/v1/event", {
      method: "POST",
      headers: { "content-type": "application/json", "x-app-token": "secret" },
      body: JSON.stringify({ event: "paywall_shown", trigger: "free_limit" }),
    });
    const resp = await worker.fetch(req, makeEnv(new MockKV()));
    expect(resp.status).toBe(200);
  });

  it("rejects an event with a missing/oversized name", async () => {
    const req = new Request("https://worker.test/v1/event", {
      method: "POST",
      headers: { "content-type": "application/json", "x-app-token": "secret" },
      body: JSON.stringify({ trigger: "x" }),
    });
    const resp = await worker.fetch(req, makeEnv(new MockKV()));
    expect(resp.status).toBe(400);
  });
});

describe("happy path and limits", () => {
  it("returns the draft, decrements the free counter and reports usage", async () => {
    const kv = new MockKV();
    const resp = await worker.fetch(makeRequest(), makeEnv(kv));
    expect(resp.status).toBe(200);
    const data = (await resp.json()) as Record<string, any>;
    expect(data.draft).toEqual(DRAFT);
    expect(data.meta.remaining_free).toBe(4);
    expect(data.meta.usage.input_tokens).toBe(5000);
    expect(kv.store.get("total:device-12345678")).toBe("1");
  });

  it("blocks the 6th free listing with 402 and does not leak is_pro", async () => {
    const kv = new MockKV();
    kv.store.set("total:device-12345678", "5");
    const resp = await worker.fetch(makeRequest(), makeEnv(kv));
    expect(resp.status).toBe(402);
    const data = (await resp.json()) as Record<string, unknown>;
    expect(data.error).toBe("free_limit_reached");
    expect("is_pro" in data).toBe(false); // оракул для перебора RC-ID закрыт
    expect(createMock).not.toHaveBeenCalled();
  });

  it("returns 503 when the global daily cap is reached, before any model call", async () => {
    const kv = new MockKV();
    kv.store.set(`global:${new Date().toISOString().slice(0, 10)}`, "5000");
    const resp = await worker.fetch(makeRequest(), makeEnv(kv));
    expect(resp.status).toBe(503);
    expect(createMock).not.toHaveBeenCalled();
  });

  it("increments the global counter on a successful generation", async () => {
    const kv = new MockKV();
    await worker.fetch(makeRequest(), makeEnv(kv));
    expect(kv.store.get(`global:${new Date().toISOString().slice(0, 10)}`)).toBe("1");
  });

  it("does NOT charge a free listing when the item is not recognized", async () => {
    createMock.mockResolvedValueOnce(
      modelResponse(JSON.stringify({ recognized: false, confidence: "low", title: "", retry_hint: "photograph the tag" })),
    );
    const kv = new MockKV();
    const resp = await worker.fetch(makeRequest(), makeEnv(kv));
    expect(resp.status).toBe(200);
    const data = (await resp.json()) as Record<string, any>;
    // Free-попытка не списана, но day и global выросли (анти-абьюз + бюджет)
    expect(kv.store.has("total:device-12345678")).toBe(false);
    expect(data.meta.remaining_free).toBe(5);
    expect(kv.store.get(`global:${new Date().toISOString().slice(0, 10)}`)).toBe("1");
  });

  it("enforces the daily cap with 402", async () => {
    const kv = new MockKV();
    kv.store.set(`day:device-12345678:${new Date().toISOString().slice(0, 10)}`, "300");
    const resp = await worker.fetch(makeRequest(), makeEnv(kv));
    expect(resp.status).toBe(402);
    const data = (await resp.json()) as Record<string, unknown>;
    expect(data.error).toBe("daily_cap_reached");
  });

  it("gives pro users unlimited listings (dev-mode debug header)", async () => {
    const kv = new MockKV();
    kv.store.set("total:device-12345678", "50");
    const resp = await worker.fetch(
      makeRequest({ headers: { "x-debug-pro": "1" } }),
      makeEnv(kv, { DEV_MODE: "1" }),
    );
    expect(resp.status).toBe(200);
    const data = (await resp.json()) as Record<string, any>;
    expect(data.meta.remaining_free).toBe(-1);
    // total не растёт для pro
    expect(kv.store.get("total:device-12345678")).toBe("50");
  });
});

describe("model errors", () => {
  it("maps retryable API errors to 503 and does not charge the attempt", async () => {
    const { default: Anthropic } = (await import("@anthropic-ai/sdk")) as any;
    createMock.mockRejectedValueOnce(new Anthropic.APIError(429));
    const kv = new MockKV();
    const resp = await worker.fetch(makeRequest(), makeEnv(kv));
    expect(resp.status).toBe(503);
    expect(kv.store.has("total:device-12345678")).toBe(false);
  });

  it("returns 502 on non-JSON model output without charging", async () => {
    createMock.mockResolvedValueOnce(modelResponse("not json at all"));
    const kv = new MockKV();
    const resp = await worker.fetch(makeRequest(), makeEnv(kv));
    expect(resp.status).toBe(502);
    expect(kv.store.has("total:device-12345678")).toBe(false);
  });
});
