// Прогон тестового набора фото через воркер (шаг 1 порядка работы).
// Структура: test/sets/<имя-кейса>/*.jpg (1-3 фото на кейс).
// Запуск:  node test/run-test-set.mjs http://localhost:8787 [platform]
// Перед запуском: npx wrangler dev  (в другом терминале)

import { readdir, readFile, writeFile } from "node:fs/promises";
import { join, extname } from "node:path";

const baseUrl = process.argv[2] ?? "http://localhost:8787";
const platform = process.argv[3] ?? "ebay";
const setsDir = new URL("./sets/", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");

const MEDIA = { ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp" };

const cases = (await readdir(setsDir, { withFileTypes: true })).filter((d) => d.isDirectory());
if (cases.length === 0) {
  console.log(`Положите тестовые кейсы в ${setsDir}<case-name>/*.jpg и запустите снова.`);
  process.exit(0);
}

const results = [];
for (const c of cases) {
  const dir = join(setsDir, c.name);
  const files = (await readdir(dir)).filter((f) => MEDIA[extname(f).toLowerCase()]).slice(0, 3);
  if (files.length === 0) continue;

  const images = [];
  for (const f of files) {
    const buf = await readFile(join(dir, f));
    images.push({ data: buf.toString("base64"), media_type: MEDIA[extname(f).toLowerCase()] });
  }

  const started = Date.now();
  const resp = await fetch(`${baseUrl}/v1/listing`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-device-id": "test-device-0001",
      "x-debug-pro": "1", // работает только при DEV_MODE=1
    },
    body: JSON.stringify({ images, platform, currency: "USD" }),
  });
  const elapsed = ((Date.now() - started) / 1000).toFixed(1);
  const data = await resp.json();

  const d = data.draft ?? {};
  console.log(
    `[${c.name}] ${resp.status} ${elapsed}s | recognized=${d.recognized} conf=${d.confidence} brand=${d.brand} | "${(d.title ?? "").slice(0, 60)}"`,
  );
  if (data.meta?.usage) {
    const u = data.meta.usage;
    // Себестоимость по тарифам Sonnet 4.6: $3/M вход, $15/M выход
    const cost = (u.input_tokens * 3 + u.output_tokens * 15) / 1_000_000;
    console.log(`         tokens in=${u.input_tokens} out=${u.output_tokens} cost~$${cost.toFixed(4)}`);
  }
  results.push({ case: c.name, status: resp.status, seconds: Number(elapsed), ...data });
}

await writeFile(join(setsDir, "..", "results.json"), JSON.stringify(results, null, 2));
console.log(`\nИтоги сохранены в test/results.json (${results.length} кейсов)`);
