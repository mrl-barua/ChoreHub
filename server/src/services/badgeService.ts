// Pure functions — no Prisma dependency. All data is passed in by the caller.
//
// Badge service: stateless threshold map for category-badge tiers.
// Categories are user-supplied freeform strings (Chore.category in schema.prisma
// has no enum), so this module never assumes a fixed category list — it
// normalizes whatever string it receives into a stable badge key.

export const BADGE_THRESHOLDS = { BRONZE: 25, SILVER: 100, GOLD: 250 } as const;
export const TIER_ORDER = ['BRONZE', 'SILVER', 'GOLD'] as const;

export type BadgeTier = (typeof TIER_ORDER)[number];

export type CheckBadgesInput = {
  completionsByCategory: Record<string, number>;
  existingBadgeKeys: string[];
};

// ---------------------------------------------------------------------------
// categoryToBadgeKey
// ---------------------------------------------------------------------------
// Normalize a freeform category string into UPPERCASE_SNAKE_CASE and append
// the tier. Rule: replace every run of non-alphanumeric characters (whitespace,
// punctuation, symbols) with a single underscore, strip leading/trailing
// underscores, then uppercase. Examples:
//   "Kitchen"          + BRONZE -> "KITCHEN_BRONZE"
//   "Pet Care"         + SILVER -> "PET_CARE_SILVER"
//   "Outdoor / Yard"   + GOLD   -> "OUTDOOR_YARD_GOLD"
//   "A&B"              + GOLD   -> "A_B_GOLD"
//   "pet  care"        + SILVER -> "PET_CARE_SILVER"
export function categoryToBadgeKey(category: string, tier: BadgeTier): string {
  const normalized = category
    .replace(/[^A-Za-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .toUpperCase();
  return `${normalized}_${tier}`;
}

// ---------------------------------------------------------------------------
// checkBadges
// ---------------------------------------------------------------------------
// Decision: when a category's completion count jumps over a tier (e.g., 150
// completions and BRONZE was never earned yet), award ALL crossed tiers in
// deterministic order — BRONZE then SILVER then GOLD. The kid is owed the
// lower tiers; missing them would silently drop badges they earned.
//
// Return order: by category name alphabetically (case-sensitive on the raw
// key), then tier ascending (BRONZE before SILVER before GOLD). Stable and
// deterministic for identical inputs.
export function checkBadges(input: CheckBadgesInput): string[] {
  const { completionsByCategory, existingBadgeKeys } = input;
  const existing = new Set(existingBadgeKeys);
  const newlyEarned: string[] = [];

  // Sort categories alphabetically for deterministic output order.
  const categories = Object.keys(completionsByCategory).sort();

  for (const category of categories) {
    // Skip empty/whitespace-only category strings — they would normalize to
    // an empty prefix and produce keys like "_BRONZE" which are meaningless.
    if (!category || category.trim().length === 0) continue;

    const count = completionsByCategory[category];
    if (typeof count !== 'number' || count <= 0) continue;

    for (const tier of TIER_ORDER) {
      const threshold = BADGE_THRESHOLDS[tier];
      if (count < threshold) continue;

      const key = categoryToBadgeKey(category, tier);
      if (existing.has(key)) continue;

      newlyEarned.push(key);
    }
  }

  return newlyEarned;
}
