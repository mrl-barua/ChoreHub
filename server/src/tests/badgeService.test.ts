import { describe, it, expect } from 'vitest';
import {
  BADGE_THRESHOLDS,
  TIER_ORDER,
  categoryToBadgeKey,
  checkBadges,
} from '../services/badgeService';

// ---------------------------------------------------------------------------
// Constants sanity
// ---------------------------------------------------------------------------
describe('BADGE_THRESHOLDS / TIER_ORDER', () => {
  it('thresholds are 25 / 100 / 250', () => {
    expect(BADGE_THRESHOLDS.BRONZE).toBe(25);
    expect(BADGE_THRESHOLDS.SILVER).toBe(100);
    expect(BADGE_THRESHOLDS.GOLD).toBe(250);
  });

  it('tier order is BRONZE, SILVER, GOLD', () => {
    expect(TIER_ORDER).toEqual(['BRONZE', 'SILVER', 'GOLD']);
  });
});

// ---------------------------------------------------------------------------
// categoryToBadgeKey
// ---------------------------------------------------------------------------
describe('categoryToBadgeKey', () => {
  it('"Kitchen" + BRONZE → "KITCHEN_BRONZE"', () => {
    expect(categoryToBadgeKey('Kitchen', 'BRONZE')).toBe('KITCHEN_BRONZE');
  });

  it('"pet  care" + SILVER → "PET_CARE_SILVER" (collapses multi-space)', () => {
    expect(categoryToBadgeKey('pet  care', 'SILVER')).toBe('PET_CARE_SILVER');
  });

  it('"A&B" + GOLD → "A_B_GOLD"', () => {
    expect(categoryToBadgeKey('A&B', 'GOLD')).toBe('A_B_GOLD');
  });

  it('"Pet Care" + SILVER → "PET_CARE_SILVER"', () => {
    expect(categoryToBadgeKey('Pet Care', 'SILVER')).toBe('PET_CARE_SILVER');
  });

  it('"Outdoor / Yard" + GOLD → "OUTDOOR_YARD_GOLD"', () => {
    expect(categoryToBadgeKey('Outdoor / Yard', 'GOLD')).toBe('OUTDOOR_YARD_GOLD');
  });

  it('"kitchen" + BRONZE → "KITCHEN_BRONZE" (lowercase normalized)', () => {
    expect(categoryToBadgeKey('kitchen', 'BRONZE')).toBe('KITCHEN_BRONZE');
  });
});

// ---------------------------------------------------------------------------
// checkBadges
// ---------------------------------------------------------------------------
describe('checkBadges', () => {
  it('empty completionsByCategory and empty existingBadgeKeys → []', () => {
    expect(
      checkBadges({ completionsByCategory: {}, existingBadgeKeys: [] }),
    ).toEqual([]);
  });

  it('below threshold: { Kitchen: 24 } → []', () => {
    expect(
      checkBadges({
        completionsByCategory: { Kitchen: 24 },
        existingBadgeKeys: [],
      }),
    ).toEqual([]);
  });

  it('exact bronze threshold: { Kitchen: 25 } → ["KITCHEN_BRONZE"]', () => {
    expect(
      checkBadges({
        completionsByCategory: { Kitchen: 25 },
        existingBadgeKeys: [],
      }),
    ).toEqual(['KITCHEN_BRONZE']);
  });

  it('exact silver threshold with no existing → both BRONZE and SILVER (jumped tier)', () => {
    expect(
      checkBadges({
        completionsByCategory: { Kitchen: 100 },
        existingBadgeKeys: [],
      }),
    ).toEqual(['KITCHEN_BRONZE', 'KITCHEN_SILVER']);
  });

  it('exact gold threshold with no existing → all three tiers', () => {
    expect(
      checkBadges({
        completionsByCategory: { Kitchen: 250 },
        existingBadgeKeys: [],
      }),
    ).toEqual(['KITCHEN_BRONZE', 'KITCHEN_SILVER', 'KITCHEN_GOLD']);
  });

  it('idempotency: { Kitchen: 30 } with existing BRONZE → []', () => {
    expect(
      checkBadges({
        completionsByCategory: { Kitchen: 30 },
        existingBadgeKeys: ['KITCHEN_BRONZE'],
      }),
    ).toEqual([]);
  });

  it('skip-tier with existing: { Kitchen: 100 } with BRONZE earned → ["KITCHEN_SILVER"] only', () => {
    expect(
      checkBadges({
        completionsByCategory: { Kitchen: 100 },
        existingBadgeKeys: ['KITCHEN_BRONZE'],
      }),
    ).toEqual(['KITCHEN_SILVER']);
  });

  it('multiple categories sorted alphabetically; below-threshold contributes nothing', () => {
    expect(
      checkBadges({
        completionsByCategory: { Kitchen: 25, Pets: 100, Outdoor: 5 },
        existingBadgeKeys: [],
      }),
    ).toEqual(['KITCHEN_BRONZE', 'PETS_BRONZE', 'PETS_SILVER']);
  });

  it('special characters: { "Pet Care": 25 } → ["PET_CARE_BRONZE"]', () => {
    expect(
      checkBadges({
        completionsByCategory: { 'Pet Care': 25 },
        existingBadgeKeys: [],
      }),
    ).toEqual(['PET_CARE_BRONZE']);
  });

  it('special characters: { "Outdoor / Yard": 25 } → ["OUTDOOR_YARD_BRONZE"]', () => {
    expect(
      checkBadges({
        completionsByCategory: { 'Outdoor / Yard': 25 },
        existingBadgeKeys: [],
      }),
    ).toEqual(['OUTDOOR_YARD_BRONZE']);
  });

  it('lowercase normalized: { kitchen: 25 } → ["KITCHEN_BRONZE"]', () => {
    expect(
      checkBadges({
        completionsByCategory: { kitchen: 25 },
        existingBadgeKeys: [],
      }),
    ).toEqual(['KITCHEN_BRONZE']);
  });

  it('empty category string → ignored, no crash', () => {
    expect(
      checkBadges({
        completionsByCategory: { '': 100, Kitchen: 25 },
        existingBadgeKeys: [],
      }),
    ).toEqual(['KITCHEN_BRONZE']);
  });

  it('whitespace-only category string → ignored', () => {
    expect(
      checkBadges({
        completionsByCategory: { '   ': 100 },
        existingBadgeKeys: [],
      }),
    ).toEqual([]);
  });

  it('zero count → no badges', () => {
    expect(
      checkBadges({
        completionsByCategory: { Kitchen: 0 },
        existingBadgeKeys: [],
      }),
    ).toEqual([]);
  });

  it('negative count → no badges', () => {
    expect(
      checkBadges({
        completionsByCategory: { Kitchen: -50 },
        existingBadgeKeys: [],
      }),
    ).toEqual([]);
  });

  it('massive count > 250 → all three tiers, no extra', () => {
    const result = checkBadges({
      completionsByCategory: { Kitchen: 99999 },
      existingBadgeKeys: [],
    });
    expect(result).toEqual([
      'KITCHEN_BRONZE',
      'KITCHEN_SILVER',
      'KITCHEN_GOLD',
    ]);
    expect(result).toHaveLength(3);
  });

  it('determinism: identical inputs produce identical outputs in identical order', () => {
    const input = {
      completionsByCategory: { Pets: 250, Kitchen: 100, Outdoor: 25 },
      existingBadgeKeys: [],
    };
    const a = checkBadges(input);
    const b = checkBadges(input);
    expect(a).toEqual(b);
    expect(a).toEqual([
      'KITCHEN_BRONZE',
      'KITCHEN_SILVER',
      'OUTDOOR_BRONZE',
      'PETS_BRONZE',
      'PETS_SILVER',
      'PETS_GOLD',
    ]);
  });
});
