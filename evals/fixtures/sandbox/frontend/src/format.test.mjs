import { test } from 'node:test';
import assert from 'node:assert/strict';

import { formatAccountId, formatBalance } from './format.mjs';

test('formatAccountId strips the prefix', () => {
  assert.equal(formatAccountId('acc-1001'), '#1001');
});

test('formatAccountId rejects anything that is not an account id', () => {
  assert.throws(() => formatAccountId('1001'), /not an account id/);
  assert.throws(() => formatAccountId(undefined), /not an account id/);
});

test('formatBalance renders minor units with a comma separator', () => {
  assert.equal(formatBalance(1250050, 'EUR'), '12500,50 EUR');
  assert.equal(formatBalance(0, 'EUR'), '0,00 EUR');
});

test('formatBalance rejects non-integer input', () => {
  assert.throws(() => formatBalance(12.5, 'EUR'), /minor units/);
});
