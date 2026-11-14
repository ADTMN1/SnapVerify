import { normalizeTransactionId } from './reference-normalizer';

describe('normalizeTransactionId (Stage 1 — safest normalization)', () => {
  it('trims leading and trailing whitespace only', () => {
    expect(normalizeTransactionId('  FT123  ')).toBe('FT123');
    expect(normalizeTransactionId('\t FT123 \n')).toBe('FT123');
  });

  it('PRESERVES letter case (Leul.et case-insensitivity is unconfirmed)', () => {
    expect(normalizeTransactionId('ft123')).toBe('ft123');
    expect(normalizeTransactionId('Ft123')).toBe('Ft123');
    expect(normalizeTransactionId('ft123')).not.toBe(
      normalizeTransactionId('FT123'),
    );
  });

  it('PRESERVES internal whitespace (Leul.et whitespace insignificance is unconfirmed)', () => {
    expect(normalizeTransactionId('FT 1234')).toBe('FT 1234');
    expect(normalizeTransactionId('FT  1234')).toBe('FT  1234');
    expect(normalizeTransactionId('FT 1234')).not.toBe(
      normalizeTransactionId('FT1234'),
    );
  });

  it('PRESERVES separators (their significance is unconfirmed)', () => {
    expect(normalizeTransactionId('FT-1234-5678')).toBe('FT-1234-5678');
    expect(normalizeTransactionId('FT_1234.5678')).toBe('FT_1234.5678');
  });

  it('never merges references that differ beyond surrounding whitespace (collision tests)', () => {
    const pairs: [string, string][] = [
      ['AB-C', 'A-BC'],
      ['FT12345678', 'FT12345679'],
      ['FT12345678', 'FT1234567'],
      ['ft123', 'FT123'],
      ['FT 123', 'FT123'],
      ['FT-1001', 'FT10-01'],
    ];
    for (const [a, b] of pairs) {
      expect(normalizeTransactionId(a)).not.toBe(normalizeTransactionId(b));
    }
  });

  it('is deterministic: surrounding-whitespace variants of one reference collide', () => {
    const inputs = ['FT12345678', ' FT12345678 ', '\tFT12345678\n'];
    expect(new Set(inputs.map(normalizeTransactionId)).size).toBe(1);
  });

  it('maps empty and whitespace-only references to null', () => {
    expect(normalizeTransactionId('')).toBeNull();
    expect(normalizeTransactionId('   ')).toBeNull();
    expect(normalizeTransactionId('\t\n')).toBeNull();
  });

  it('maps non-string input to null (defense in depth)', () => {
    expect(normalizeTransactionId(null)).toBeNull();
    expect(normalizeTransactionId(undefined)).toBeNull();
    expect(normalizeTransactionId(12345)).toBeNull();
    expect(normalizeTransactionId({ ref: 'X' })).toBeNull();
  });
});
