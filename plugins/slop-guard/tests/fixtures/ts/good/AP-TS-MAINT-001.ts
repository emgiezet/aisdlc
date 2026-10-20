import { accountSchema, tokenSchema, type Account } from './schema';

// ok: slopguard.ts.double-cast
export function loadAccount(input: unknown): Account {
  return accountSchema.parse(input);
}

// ok: slopguard.ts.double-cast
export function readToken(res: Response): { token: string } {
  return tokenSchema.parse(res.body);
}

// ok: slopguard.ts.double-cast
// A single narrowing cast from a typed value is not the double-cast pattern;
// ESLint's no-explicit-any / no-non-null-assertion cover the rest of AP-TS-MAINT-001.
export function widen(account: Account): Record<string, unknown> {
  return account as Record<string, unknown>;
}

// ok: slopguard.ts.double-cast
export function isAccount(value: unknown): value is Account {
  return accountSchema.safeParse(value).success;
}
