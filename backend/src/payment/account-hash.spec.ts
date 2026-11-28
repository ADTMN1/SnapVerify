import * as crypto from 'crypto';
import {
  ACCOUNT_HASH_PREFIX,
  computeAccountNumberHash,
  normalizeAccountNumber,
  parseAccountHashVersion,
} from './account-hash';

const SECRET = 'a'.repeat(48);

describe('account-hash (Stage 1 review: keyed HMAC-SHA-256)', () => {
  it('normalizes account numbers structurally', () => {
    expect(normalizeAccountNumber('1000 5163-23381')).toBe('1000516323381');
    expect(normalizeAccountNumber('')).toBeNull();
    expect(normalizeAccountNumber(null)).toBeNull();
  });

  it('produces a versioned hmac-v1 hash distinct from plain SHA-256', () => {
    const hash = computeAccountNumberHash('1000516323381', SECRET);
    expect(hash).toMatch(/^hmac-v1:[0-9a-f]{64}$/);
    const plain = crypto
      .createHash('sha256')
      .update('1000516323381')
      .digest('hex');
    expect(hash!.slice(ACCOUNT_HASH_PREFIX.length)).not.toBe(plain);
  });

  it('matches HMAC-SHA-256 computed independently (deterministic, keyed)', () => {
    const hash = computeAccountNumberHash('1000 5163-23381', SECRET);
    const expected =
      ACCOUNT_HASH_PREFIX +
      crypto.createHmac('sha256', SECRET).update('1000516323381').digest('hex');
    expect(hash).toBe(expected);
  });

  it('a different secret produces a different hash (keyed, not enumerable)', () => {
    const a = computeAccountNumberHash('1000516323381', SECRET);
    const b = computeAccountNumberHash('1000516323381', 'b'.repeat(48));
    expect(a).not.toBe(b);
  });

  it('is NOT the plain SHA-256 of the normalized number (offline guessing defense)', () => {
    // With a keyed HMAC, a database leak cannot be brute-forced by
    // enumerating the 10^8-10^13 digit keyspace.
    const hash = computeAccountNumberHash('1000516323381', SECRET);
    const shaOfAllCandidates = crypto
      .createHash('sha256')
      .update('1000516323381')
      .digest('hex');
    expect(hash!.startsWith(ACCOUNT_HASH_PREFIX)).toBe(true);
    expect(hash!.includes(shaOfAllCandidates)).toBe(false);
  });

  it('refuses to compute with a missing or short secret (fail closed)', () => {
    expect(() => computeAccountNumberHash('1000516323381', '')).toThrow(
      /ACCOUNT_HASH_SECRET/,
    );
    expect(() => computeAccountNumberHash('1000516323381', 'short')).toThrow(
      /ACCOUNT_HASH_SECRET/,
    );
  });

  it('maps empty account numbers to null hash', () => {
    expect(computeAccountNumberHash(null, SECRET)).toBeNull();
    expect(computeAccountNumberHash('   ', SECRET)).toBeNull();
  });

  it('parses stored hash versions', () => {
    expect(
      parseAccountHashVersion(computeAccountNumberHash('1234', SECRET)),
    ).toBe('hmac-v1');
    // Legacy plain sha256 from earlier builds is NOT recognized as hmac-v1.
    expect(
      parseAccountHashVersion(
        crypto.createHash('sha256').update('1234').digest('hex'),
      ),
    ).toBeNull();
    expect(parseAccountHashVersion(null)).toBeNull();
  });

  describe('Ethiopian phone number canonicalization', () => {
    it('all written formats canonicalize to the same local number', () => {
      const expected = '0986006897';
      expect(normalizeAccountNumber('0986006897')).toBe(expected);
      expect(normalizeAccountNumber('+251986006897')).toBe(expected);
      expect(normalizeAccountNumber('251986006897')).toBe(expected);
      expect(normalizeAccountNumber('09-860-068-97')).toBe(expected);
      expect(normalizeAccountNumber('(09) 860 068 97')).toBe(expected);
    });

    it('every equivalent format produces the SAME hmac-v1 hash', () => {
      const expected = computeAccountNumberHash('0986006897', SECRET);
      expect(computeAccountNumberHash('+251986006897', SECRET)).toBe(expected);
      expect(computeAccountNumberHash('251986006897', SECRET)).toBe(expected);
      expect(computeAccountNumberHash('09-860-068-97', SECRET)).toBe(expected);
    });

    it('different phone numbers never collide', () => {
      const a = computeAccountNumberHash('0986006897', SECRET);
      const b = computeAccountNumberHash('0919779032', SECRET);
      const c = computeAccountNumberHash('251986006898', SECRET);
      expect(a).not.toBe(b);
      expect(a).not.toBe(c);
    });

    it('does NOT alter bank account numbers (CBE/BOA compatibility)', () => {
      expect(normalizeAccountNumber('1000516323381')).toBe('1000516323381');
      expect(normalizeAccountNumber('1000 5163-23381')).toBe('1000516323381');
      expect(normalizeAccountNumber('1000290172')).toBe('1000290172');
      // A 10-digit bank number that merely starts with digits is untouched
      // unless it matches the 0[97] Ethiopian mobile pattern.
      expect(normalizeAccountNumber('1234567890')).toBe('1234567890');
    });

    it('07-prefixed mobile numbers canonicalize too', () => {
      expect(normalizeAccountNumber('+251712345678')).toBe('0712345678');
      expect(normalizeAccountNumber('07-123-456-78')).toBe('0712345678');
    });
  });
});
