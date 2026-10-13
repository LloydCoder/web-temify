# Prisma schema ownership

No production schema or migrations are added until ADR-0003 is accepted. Decide whether Prisma Migrate or Supabase SQL migrations are authoritative, then document drift detection and CI enforcement. Validate the existing proposed schema before importing it; table counts in historical documents are not accepted as verified schema.