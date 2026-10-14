import { z } from "zod";

export const SettlementExceptionDecisionSchema = z
  .object({
    rowId: z.string().min(1).max(240),
    decision: z.enum([
      "reimport_required",
      "manual_review_required",
      "accepted_with_evidence",
    ]),
    reason: z.string().trim().min(12).max(500),
    evidenceSha256: z.string().regex(/^[a-f0-9]{64}$/).nullable(),
  })
  .strict()
  .superRefine((value, context) => {
    if (
      value.decision === "accepted_with_evidence" &&
      value.evidenceSha256 === null
    ) {
      context.addIssue({
        code: "custom",
        path: ["evidenceSha256"],
        message: "Evidence digest is required for this decision.",
      });
    }
    if (
      value.decision !== "accepted_with_evidence" &&
      value.evidenceSha256 !== null
    ) {
      context.addIssue({
        code: "custom",
        path: ["evidenceSha256"],
        message: "Evidence digest is only allowed for evidence-backed triage.",
      });
    }
  });
