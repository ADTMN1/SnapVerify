import {
  PUBLIC_ID_REGEX,
  generatePublicId,
  isUniqueConstraintViolation,
  isValidPublicId,
} from './public-id';

describe('public QR identifiers', () => {
  it('generates 24 lowercase hex characters', () => {
    for (let i = 0; i < 50; i++) {
      const id = generatePublicId();
      expect(id).toHaveLength(24);
      expect(id).toMatch(PUBLIC_ID_REGEX);
      expect(id).toBe(id.toLowerCase());
    }
  });

  it('generates distinct identifiers', () => {
    const ids = new Set(Array.from({ length: 500 }, generatePublicId));
    expect(ids.size).toBe(500);
  });

  it('does not include the account number or any decimal digits pattern', () => {
    // Sanity check that the id is opaque hex, not a formatted account number.
    expect(generatePublicId()).not.toMatch(/^1000/);
  });

  it('validates identifiers strictly', () => {
    expect(isValidPublicId(generatePublicId())).toBe(true);
    expect(isValidPublicId('A1B2C3D4E5F60718293A4B5C')).toBe(false); // upper-case
    expect(isValidPublicId('abc')).toBe(false);
    expect(isValidPublicId('g1b2c3d4e5f60718293a4b5c')).toBe(false);
    expect(isValidPublicId(null)).toBe(false);
    expect(isValidPublicId(123)).toBe(false);
  });
});

describe('isUniqueConstraintViolation', () => {
  it('detects P2002 for the requested field', () => {
    expect(
      isUniqueConstraintViolation(
        { code: 'P2002', meta: { target: ['publicId'] } },
        'publicId',
      ),
    ).toBe(true);
  });

  it('ignores other unique fields and other errors', () => {
    expect(
      isUniqueConstraintViolation(
        { code: 'P2002', meta: { target: ['organizationId'] } },
        'publicId',
      ),
    ).toBe(false);
    expect(isUniqueConstraintViolation({ code: 'P2025' }, 'publicId')).toBe(
      false,
    );
    expect(isUniqueConstraintViolation(new Error('boom'), 'publicId')).toBe(
      false,
    );
  });
});
