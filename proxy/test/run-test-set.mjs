// Прогон тестового набора через ЖИВОЙ воркер (шаг 1 порядка работы).
// Структура: test/sets/<кейс>/*.jpg (1-3 фото), ожидания — в test/manifest.json.
// Запуск (Windows, через локальный прокси):
//   $env:NODE_USE_ENV_PROXY="1"; $env:HTTPS_PROXY="http://127.0.0.1:12334"
//   node test/run-test-set.mjs [baseUrl]
// Токен берётся из APP_TOKEN или ../secrets.local.txt.

import { readdir, readFile, writeFile } from "node:fs/promises";
import { join, extname, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const setsDir = join(here, "sets");
const baseUrl = process.argv[2] ?? "https://resell-scanner-proxy.sane4ek07.workers.dev";

const MEDIA = { ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp" };
// Tier 1: 30K input-токенов/мин без кэша, ~2.8K на кейс -> пауза держит ~8 кейсов/мин
const DELAY_MS = 7000;
const delay = (ms) => new Promise((r) => setTimeout(r, ms));

let token = process.env.APP_TOKEN;
if (!token) {
  try {
    const secrets = await readFile(join(here, "..", "..", "secrets.local.txt"), "utf8");
    token = secrets.match(/APP_SHARED_SECRET=(\S+)/)?.[1];
  } catch { /* секретов нет — воркер без APP_SHARED_SECRET пропустит и так */ }
}

let manifest = {};
try {
  manifest = JSON.parse(await readFile(join(here, "manifest.json"), "utf8"));
} catch { /* без манифеста все кейсы идут как ebay без ожиданий */ }

const cases = (await readdir(setsDir, { withFileTypes: true }))
  .filter((d) => d.isDirectory())
  .map((d) => d.name)
  .sort();

if (cases.length === 0) {
  console.log(`Положите кейсы в ${setsDir}/<имя>/*.jpg и запустите снова.`);
  process.exit(0);
}

const results = [];
for (const name of cases) {
  const cfg = manifest[name] ?? { platform: "ebay" };
  const dir = join(setsDir, name);
  const files = (await readdir(dir))
    .filter((f) => MEDIA[extname(f).toLowerCase()])
    .sort()
    .slice(0, 3);
  if (files.length === 0) continue;

  const images = [];
  for (const f of files) {
    const buf = await readFile(join(dir, f));
    images.push({ data: buf.toString("base64"), media_type: MEDIA[extname(f).toLowerCase()] });
  }

  const body = { images, platform: cfg.platform ?? "ebay", currency: "USD" };
  if (cfg.note) body.note = cfg.note;

  const started = Date.now();
  let resp, data;
  try {
    resp = await fetch(`${baseUrl}/v1/listing`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-app-token": token ?? "",
        // Свой device-id на кейс: free-лимит 5/устройство не мешает прогону
        "x-device-id": `testrun-${name}`.slice(0, 64),
      },
      body: JSON.stringify(body),
    });
    data = await resp.json();
  } catch (e) {
    console.log(`[${name}] FETCH ERROR: ${e.message}`);
    results.push({ case: name, error: String(e.message) });
    await delay(DELAY_MS);
    continue;
  }
  const seconds = Number(((Date.now() - started) / 1000).toFixed(1));

  const d = data.draft ?? {};
  const u = data.meta?.usage;
  // Sonnet 4.6: $3/M вход, $0.30/M кэш-чтение, $15/M выход
  const cost = u
    ? Number(((u.input_tokens * 3 + (u.cache_read_input_tokens ?? 0) * 0.3 + u.output_tokens * 15) / 1e6).toFixed(4))
    : null;

  console.log(
    `[${name}] ${resp.status} ${seconds}s $${cost ?? "?"} | rec=${d.recognized} conf=${d.confidence} brand=${d.brand} size=${d.size} | "${(d.title ?? "").slice(0, 55)}"`,
  );

  results.push({
    case: name,
    platform: cfg.platform ?? "ebay",
    photos: files.length,
    expect: cfg.expect ?? null,
    status: resp.status,
    seconds,
    cost,
    usage: u ?? null,
    draft: data.draft ?? data,
  });
  await delay(DELAY_MS);
}

await writeFile(join(here, "results.json"), JSON.stringify(results, null, 2));

const ok = results.filter((r) => r.status === 200);
const recognized = ok.filter((r) => r.draft?.recognized === true);
const totalCost = ok.reduce((s, r) => s + (r.cost ?? 0), 0);
const avgSec = ok.length ? (ok.reduce((s, r) => s + r.seconds, 0) / ok.length).toFixed(1) : "?";
console.log(`\n=== ИТОГО: ${ok.length}/${results.length} ответили 200, recognized=${recognized.length}, средняя латентность ${avgSec}s, суммарно $${totalCost.toFixed(3)} ===`);
console.log(`Подробности: test/results.json`);
