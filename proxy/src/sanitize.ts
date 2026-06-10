// Серверная пост-валидация черновика перед отдачей клиенту.
// Цель — убрать из объявления каналы увода сделки, проникшие через prompt
// injection (note или текст на фото): ссылки, email, мессенджеры, телефоны.
//
// ВАЖНО для домена ресейла: длинные цифровые коды — это артикулы (Nike style
// code 555088-101), ISBN, серийники, IMEI — их РЕЗАТЬ НЕЛЬЗЯ. Телефон вырезаем
// только при явных признаках: международный формат с «+» или телефонное
// ключевое слово рядом (call/text/whatsapp и т.п.).

const URL_RE = /\b(?:https?:\/\/|www\.)\S+/gi;
// Шорт-домены мессенджеров/линктри без http-префикса
const SHORTLINK_RE = /\b(?:t\.me|wa\.me|telegram\.me|bit\.ly|tinyurl\.com|linktr\.ee|cash\.app|venmo\.com|instagram\.com|facebook\.com|snapchat\.com)\/\S+/gi;
const EMAIL_RE = /\b[\w.+-]+@[\w-]+(?:\.[\w-]+)+\b/g;
// «telegram @handle», «insta: @user» — хэндл после ключевого слова соцсети
const HANDLE_RE = /\b(?:telegram|tg|insta|instagram|snap|snapchat|venmo|cashapp|whatsapp|viber|signal)\b[\s:.-]{0,4}@?\w{3,}/gi;
// Телефон в международном формате: начинается с «+», 9+ цифр
const INTL_PHONE_RE = /\+\d[\d\s().-]{7,}\d/g;
// Телефон с явным контекстом: call/text/phone/... + цифровая последовательность
const CONTEXT_PHONE_RE = /\b(?:call|text|tel|phone|whatsapp|viber|dial|sms)\b[\s:.-]{0,6}\+?\(?\d[\d\s().-]{6,}\d/gi;

function clean(text: string): string {
  return text
    .replace(URL_RE, "")
    .replace(SHORTLINK_RE, "")
    .replace(EMAIL_RE, "")
    .replace(HANDLE_RE, "")
    .replace(INTL_PHONE_RE, "")
    .replace(CONTEXT_PHONE_RE, "")
    // схлопываем лишние пробелы, СОХРАНЯЯ переводы строк (вёрстка описаний)
    .replace(/[ \t]{2,}/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .replace(/[ \t]+([.,!?;:])/g, "$1")
    .trim();
}

const TEXT_FIELDS = ["title", "description", "condition_details"] as const;

export function sanitizeDraft(draft: unknown): unknown {
  if (typeof draft !== "object" || draft === null) return draft;
  const d = draft as Record<string, unknown>;
  for (const field of TEXT_FIELDS) {
    if (typeof d[field] === "string") {
      d[field] = clean(d[field] as string);
    }
  }
  return d;
}
