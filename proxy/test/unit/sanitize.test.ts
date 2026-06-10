import { describe, expect, it } from "vitest";
import { sanitizeDraft } from "../../src/sanitize";

describe("sanitizeDraft", () => {
  it("strips URLs and contact phones from text fields", () => {
    const draft = {
      recognized: true,
      title: "Nike Hoodie — buy more at http://scam.example/x",
      description: "Great condition. Call me +1 (555) 123-4567 or visit www.evil.test now",
      condition_details: "Small stain on sleeve.",
      brand: "Nike",
    };
    const out = sanitizeDraft(draft) as Record<string, string>;
    expect(out.title).toBe("Nike Hoodie — buy more at");
    expect(out.description).not.toContain("evil.test");
    expect(out.description).not.toContain("555");
    expect(out.condition_details).toBe("Small stain on sleeve.");
  });

  it("keeps legitimate sizes, years and material phrases untouched", () => {
    const draft = {
      title: "Levi's 501 Original Fit Jeans Men's 32x32 Dark Wash",
      description: "Genuine leather details, made in 2022. Like new.",
      condition_details: "No flaws.",
    };
    const out = sanitizeDraft(draft) as Record<string, string>;
    expect(out.title).toBe("Levi's 501 Original Fit Jeans Men's 32x32 Dark Wash");
    expect(out.description).toContain("Genuine leather");
    expect(out.description).toContain("2022");
  });

  it("is a no-op for non-object input", () => {
    expect(sanitizeDraft(null)).toBeNull();
    expect(sanitizeDraft("x")).toBe("x");
  });
});
