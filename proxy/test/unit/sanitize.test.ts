import { describe, expect, it } from "vitest";
import { sanitizeDraft } from "../../src/sanitize";

function run(fields: Record<string, string>): Record<string, string> {
  return sanitizeDraft({ recognized: true, ...fields }) as Record<string, string>;
}

describe("sanitizeDraft — вырезает каналы увода сделки", () => {
  it("strips URLs (http/https/www) and shortlink domains", () => {
    const out = run({
      title: "Nike Hoodie — see http://scam.example/x",
      description: "More at www.evil.test or t.me/seller or wa.me/79991234567 now",
      condition_details: "Clean.",
    });
    expect(out.title).toBe("Nike Hoodie — see");
    expect(out.description).not.toContain("evil.test");
    expect(out.description).not.toContain("t.me");
    expect(out.description).not.toContain("wa.me");
  });

  it("strips emails and social handles with platform keywords", () => {
    const out = run({
      title: "Jacket",
      description: "email me at john.doe@gmail.com or telegram @cooldeals or insta: bestseller99",
      condition_details: "OK",
    });
    expect(out.description).not.toContain("gmail.com");
    expect(out.description).not.toContain("@cooldeals");
    expect(out.description).not.toContain("bestseller99");
  });

  it("strips international phones and keyword-context phones", () => {
    const out = run({
      title: "Boots",
      description: "Call 8 (999) 123-45-67 or +1 415 555 0172 anytime",
      condition_details: "OK",
    });
    expect(out.description).not.toContain("555");
    expect(out.description).not.toContain("999");
  });
});

describe("sanitizeDraft — НЕ трогает коды товара (ядро домена ресейла)", () => {
  it("keeps style codes, ISBN, serials and IMEI", () => {
    const out = run({
      title: "Air Jordan 1 style code 555088-101 size 10",
      description: "ISBN 978-3-16-148410-0. Serial 4751002 089. IMEI 356938035643809.",
      condition_details: "UPC 012345678905 on the box.",
    });
    expect(out.title).toContain("555088-101");
    expect(out.description).toContain("978-3-16-148410-0");
    expect(out.description).toContain("4751002 089");
    expect(out.description).toContain("356938035643809");
    expect(out.condition_details).toContain("012345678905");
  });

  it("keeps sizes, years and material phrases", () => {
    const out = run({
      title: "Levi's 501 Original Fit Jeans Men's 32x32 Dark Wash",
      description: "Genuine leather details, made in 2022. Like new.",
      condition_details: "No flaws.",
    });
    expect(out.title).toBe("Levi's 501 Original Fit Jeans Men's 32x32 Dark Wash");
    expect(out.description).toContain("Genuine leather");
    expect(out.description).toContain("2022");
  });

  it("preserves paragraph line breaks", () => {
    const out = run({
      title: "T",
      description: "First paragraph.\n\nSecond paragraph.",
      condition_details: "Line one.\nLine two.",
    });
    expect(out.description).toBe("First paragraph.\n\nSecond paragraph.");
    expect(out.condition_details).toBe("Line one.\nLine two.");
  });

  it("is a no-op for non-object input", () => {
    expect(sanitizeDraft(null)).toBeNull();
    expect(sanitizeDraft("x")).toBe("x");
  });
});
