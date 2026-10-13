# ADR-0003: Database migration authority

- **Status:** Proposed — blocking before schema implementation
- **Date:** 2026-10-13

## Context
Existing documents describe Supabase PostgreSQL and Prisma while showing both Prisma and Supabase migration directories. Competing schema authorities can drift and create destructive deployments.

## Decision
Do not generate production schema or migrations until the owner chooses and validates one model:
1. Prisma Migrate owns schema evolution; Supabase CLI manages local services and coordinated RLS/functions; or
2. Supabase SQL migrations own schema evolution; Prisma is a checked representation/client.

## Required follow-up
Record the chosen owner and drift-check; define RLS/functions/triggers/extensions review; document local reset, staging, production apply, rollback/forward-fix, and backup/restore; validate with a small non-production migration.

Schema implementation is intentionally blocked until this ADR is accepted.