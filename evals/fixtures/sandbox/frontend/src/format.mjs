// Display formatting for ledger values. Amounts arrive as minor units (cents).

/** Formats an account id for display: acc-1001 → #1001. */
export function formatAccountId(id) {
  if (typeof id !== 'string' || !id.startsWith('acc-')) {
    throw new Error(`not an account id: ${id}`);
  }
  return `#${id.slice(4)}`;
}

/** Formats a balance in minor units as a localised amount with its currency. */
export function formatBalance(minorUnits, currency) {
  if (!Number.isInteger(minorUnits)) {
    throw new Error(`balance must be an integer number of minor units: ${minorUnits}`);
  }
  const major = (minorUnits / 100).toFixed(2).replace('.', ',');
  return `${major} ${currency}`;
}
