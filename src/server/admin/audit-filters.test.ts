import { describe, expect, it } from "vitest";
import { parseAuditFilters } from "./audit-filters";

describe("parseAuditFilters", () => {
  it("accepts bounded exact filters and a positive cursor", () => {
    expect(
      parseAuditFilters({
        action: "admin.product_rights.reviewed",
        entityType: "product",
        cursor: "42",
      }),
    ).toEqual({
      action: "admin.product_rights.reviewed",
      entityType: "product",
      cursor: "42",
      invalid: false,
    });
  });

  it("treats empty optional filters as absent", () => {
    expect(parseAuditFilters({ action: "", entityType: "" })).toEqual({
      invalid: false,
    });
  });

  it("rejects repeated filter parameters", () => {
    expect(
      parseAuditFilters({ action: ["admin.login", "admin.logout"] }).invalid,
    ).toBe(true);
  });

  it("rejects oversized or unsupported filter characters", () => {
    expect(parseAuditFilters({ action: "x".repeat(121) }).invalid).toBe(true);
    expect(parseAuditFilters({ action: "admin\nlogout" }).invalid).toBe(true);
    expect(parseAuditFilters({ entityType: "product/*" }).invalid).toBe(true);
  });

  it("rejects zero, signed, and oversized cursors", () => {
    expect(parseAuditFilters({ cursor: "0" }).invalid).toBe(true);
    expect(parseAuditFilters({ cursor: "-1" }).invalid).toBe(true);
    expect(parseAuditFilters({ cursor: "1".repeat(20) }).invalid).toBe(true);
    expect(parseAuditFilters({ cursor: "9999999999999999999" }).invalid).toBe(
      true,
    );
  });

  it("rejects unknown query parameters instead of silently broadening the query", () => {
    expect(parseAuditFilters({ admin: "true" }).invalid).toBe(true);
  });
});
