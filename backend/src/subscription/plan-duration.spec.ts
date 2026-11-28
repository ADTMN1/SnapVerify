import { BadRequestException } from '@nestjs/common';
import {
  addCalendarMonths,
  calculateEndDate,
  validatePlanDuration,
} from './plan-duration';

const activation = new Date('2026-01-31T10:30:00.000Z');
const activationStart = new Date('2026-01-01T00:00:00.000Z');

describe('plan duration helpers', () => {
  describe('addCalendarMonths', () => {
    it('adds calendar months and clamps to the end of shorter months', () => {
      expect(addCalendarMonths(activation, 1).toISOString()).toBe(
        '2026-02-28T10:30:00.000Z',
      );
      expect(addCalendarMonths(activation, 5).toISOString()).toBe(
        '2026-06-30T10:30:00.000Z',
      );
    });
  });

  describe('calculateEndDate', () => {
    it('expires a five-month plan five calendar months after activation', () => {
      const endDate = calculateEndDate(
        { durationMonths: 5, isLifetime: false },
        activation,
      );
      expect(endDate?.toISOString()).toBe('2026-06-30T10:30:00.000Z');
    });

    it.each([
      ['1 month', 1],
      ['3 months', 3],
      ['6 months', 6],
      ['1 year', 12],
    ])('expires %s from the activation date', (_label, months) => {
      const endDate = calculateEndDate(
        { durationMonths: months, isLifetime: false },
        activationStart,
      );
      expect(endDate).toEqual(
        new Date(Date.UTC(2026, activationStart.getUTCMonth() + months, 1)),
      );
    });

    it.each([
      ['1 month', 30],
      ['3 months', 90],
      ['6 months', 180],
      ['1 year', 360],
    ])('honors legacy %s durationDays', (_label, days) => {
      const endDate = calculateEndDate(
        { durationDays: days, isLifetime: false },
        activationStart,
      );
      expect(endDate?.getTime()).toBe(
        activationStart.getTime() + days * 86_400_000,
      );
    });

    it('keeps explicitly configured lifetime plans without expiry', () => {
      expect(
        calculateEndDate(
          { durationDays: null, durationMonths: null, isLifetime: true },
          activation,
        ),
      ).toBeNull();
    });

    it('keeps legacy plans with no duration fields without expiry', () => {
      expect(
        calculateEndDate(
          { durationDays: null, durationMonths: null, isLifetime: false },
          activation,
        ),
      ).toBeNull();
    });
  });

  describe('validatePlanDuration', () => {
    it('accepts a dynamically configured five-month duration', () => {
      expect(() =>
        validatePlanDuration({
          durationDays: null,
          durationMonths: 5,
          isLifetime: false,
        }),
      ).not.toThrow();
    });

    it('accepts an explicitly configured lifetime plan', () => {
      expect(() =>
        validatePlanDuration({
          durationDays: null,
          durationMonths: null,
          isLifetime: true,
        }),
      ).not.toThrow();
    });

    it.each([
      ['missing duration', {}],
      ['explicit non-lifetime with no duration', { isLifetime: false }],
      ['zero months', { durationMonths: 0 }],
      ['negative days', { durationDays: -1 }],
      ['fractional months', { durationMonths: 1.5 }],
    ])('rejects %s', (_label, value) => {
      expect(() => validatePlanDuration(value)).toThrow(BadRequestException);
    });

    it('rejects a lifetime plan that also has a duration', () => {
      expect(() =>
        validatePlanDuration({ durationMonths: 5, isLifetime: true }),
      ).toThrow(/Lifetime plans cannot have a duration/);
    });

    it('rejects both day and month durations', () => {
      expect(() =>
        validatePlanDuration({ durationDays: 30, durationMonths: 5 }),
      ).toThrow(/either durationDays or durationMonths/);
    });
  });
});
