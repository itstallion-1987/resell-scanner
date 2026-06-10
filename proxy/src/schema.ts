// JSON-схема ответа vision-модели (structured outputs, output_config.format).
// Ограничения structured outputs: у всех объектов additionalProperties: false,
// nullable-поля через anyOf, без min/max-констрейнтов.

const nullableString = { anyOf: [{ type: "string" }, { type: "null" }] };
const nullableNumber = { anyOf: [{ type: "number" }, { type: "null" }] };

export const LISTING_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "recognized",
    "confidence",
    "title",
    "brand",
    "model",
    "category",
    "size",
    "materials",
    "condition",
    "condition_details",
    "description",
    "keywords",
    "price_range",
    "sold_comps_query",
    "retry_hint",
  ],
  properties: {
    recognized: { type: "boolean" },
    confidence: { enum: ["high", "medium", "low"] },
    title: { type: "string", description: "Listing title within the platform's character limit, keywords first" },
    brand: { ...nullableString, description: "Brand visible on the item/tag, null if not confidently visible" },
    model: { ...nullableString, description: "Model/style name if identifiable, else null" },
    category: { type: "string", description: "Item category, e.g. 'Women's Jeans', 'Wireless Headphones'" },
    size: { ...nullableString, description: "Size from the tag if visible, else null" },
    materials: { ...nullableString, description: "Materials/composition from the tag if visible, else null" },
    condition: { enum: ["new_with_tags", "like_new", "good", "fair", "poor"] },
    condition_details: {
      type: "string",
      description: "Honest description of visible condition: every visible flaw mentioned, nothing invented",
    },
    description: { type: "string", description: "Selling description in the platform's tone" },
    keywords: { type: "array", items: { type: "string" }, description: "8-12 search keywords" },
    price_range: {
      type: "object",
      additionalProperties: false,
      required: ["low", "high", "currency", "note"],
      properties: {
        low: nullableNumber,
        high: nullableNumber,
        currency: { type: "string" },
        note: { type: "string", description: "Always a disclaimer that this is an estimate, check sold comps" },
      },
    },
    sold_comps_query: {
      type: "string",
      description: "Ready-to-paste search query to check sold listings of comparable items",
    },
    retry_hint: {
      ...nullableString,
      description: "When recognized=false or confidence=low: which specific photo angle to take (e.g. 'photograph the tag')",
    },
  },
} as const;
