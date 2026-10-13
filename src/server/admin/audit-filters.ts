import { z } from "zod";

const filterToken = z.string().trim().min(1).max(120).regex(/^[A-Za-z0-9._:-]+$/);
const cursorToken = z.string().regex(/^[1-9][0-9]{0,18}$/);

export type AuditSearchParams = Record<string, string | string[] | undefined>;

export type AuditFilters = {
  action?: string;
  entityType?: string;
  cursor?: string;
  invalid: boolean;
};

function parseOptional(
  value: string | string[] | undefined,
  schema: z.ZodType<string>
): { value?: string; invalid: boolean } {
  if (value === undefined || value === "") return { invalid: false };
  if (typeof value !== "string") return { invalid: true };
  const parsed = schema.safeParse(value);
  return parsed.success ? { value: parsed.data, invalid: false } : { invalid: true };
}

/** Parse untrusted URL search parameters before they reach database filters. */
export function parseAuditFilters(params: AuditSearchParams): AuditFilters {
  const action = parseOptional(params.action, filterToken);
  const entityType = parseOptional(params.entityType, filterToken);
  const cursor = parseOptional(params.cursor, cursorToken);
  const allowed = new Set(["action", "entityType", "cursor"]);
  const hasUnknown = Object.keys(params).some((key) => !allowed.has(key));

  return {
    action: action.value,
    entityType: entityType.value,
    cursor: cursor.value,
    invalid: action.invalid || entityType.invalid || cursor.invalid || hasUnknown
  };
}
