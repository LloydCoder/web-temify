import { describe, expect, it } from "vitest";
import {
  SettlementExceptionDecisionSchema,
} from "./settlement-exception-decision";

const baseInput = {
  rowId: "payment-row-01",
  decision: "manual_review_required" as const,
  reason: "Independent reviewer requested additional evidence.",
  evidenceSha256: null,
};

describe("SettlementExceptionDecisionSchema", () => {
  it("accepts a bounded manual-review decision without an evidence digest", () => {
    expect(SettlementExceptionDecisionSchema.safeParse(baseInput).success).toBe(
      true,
    );
  });

  it("requires a valid digest for evidence-backed triage", () => {
    expect(
      SettlementExceptionDecisionSchema.safeParse({
        ...baseInput,
        decision: "accepted_with_evidence",
        evidenceSha256: "a".repeat(64),
      }).success,
    ).toBe(true);
    expect(
      SettlementExceptionDecisionSchema.safeParse({
        ...baseInput,
        decision: "accepted_with_evidence",
      }).success,
    ).toBe(false);
  });

  it("rejects evidence digests on decisions that do not accept evidence", () => {
    expect(
      SettlementExceptionDecisionSchema.safeParse({
        ...baseInput,
        evidenceSha256: "a".repeat(64),
      }).success,
    ).toBe(false);
  });

  it("rejects extra properties, empty row identifiers, and short reasons", () => {
    expect(
      SettlementExceptionDecisionSchema.safeParse({
        ...baseInput,
        unexpected: true,
      }).success,
    ).toBe(false);
    expect(
      SettlementExceptionDecisionSchema.safeParse({
        ...baseInput,
        rowId: "",
      }).success,
    ).toBe(false);
    expect(
      SettlementExceptionDecisionSchema.safeParse({
        ...baseInput,
        reason: "short",
      }).success,
    ).toBe(false);
  });

  it("trims the decision reason before it is persisted", () => {
    const parsed = SettlementExceptionDecisionSchema.safeParse({
      ...baseInput,
      reason: "  Independent reviewer requested additional evidence.  ",
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.reason).toBe(
        "Independent reviewer requested additional evidence.",
      );
    }
  });
});
