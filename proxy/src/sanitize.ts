// Серверная пост-валидация черновика перед отдачей клиенту.
// Цель — убрать из готового объявления то, что не должно туда попасть через
// prompt injection (note или текст на фото): ссылки и контакты. Слова о
// подлинности НЕ фильтруем регуляркой — слишком много ложных срабатываний
// («genuine leather», «501 Original Fit»); за это отвечает системный промпт.

const URL_RE = /\b(?:https?:\/\/|www\.)\S+/gi;
// Длинные последовательности цифр/телефонных разделителей (7+ цифр подряд с учётом
// пробелов, дефисов, скобок) — телефоны/контакты, которым не место в описании.
const PHONE_RE = /(?:\+?\d[\d\s().-]{6,}\d)/g;

function clean(text: string): string {
  return text
    .replace(URL_RE, "")
    .replace(PHONE_RE, (m) => {
      // не трогаем короткие числа и размеры вроде «32x32», «2026»; режем только явные телефоны
      const digits = m.replace(/\D/g, "");
      return digits.length >= 9 ? "" : m;
    })
    .replace(/\s{2,}/g, " ")
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
