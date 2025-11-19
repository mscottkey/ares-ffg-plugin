import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';

export default class FfgTalentsListComponent extends Component {
  @tracked activeTier = 1;
  @tracked localTalents = null;   // local, reactive copy

  // --- Base data ---

  get char() {
    return this.args.char || {};
  }

  get cgInfo() {
    return this.args.cgInfo || {};
  }

  // Talents currently selected in chargen (reactive via localTalents).
  get purchasedTalents() {
    if (this.localTalents) {
      return this.localTalents;
    }
    const talents = this.char.talents;
    return Array.isArray(talents) ? talents : [];
  }

  // Config talents from YAML.
  get availableTalents() {
    const talents = this.cgInfo.talents;
    return Array.isArray(talents) ? talents : [];
  }

  // Map name -> { tier, rank }
  get currentTalentMap() {
    const map = Object.create(null);
    this.purchasedTalents.forEach((t) => {
      const name = t.name;
      if (!name) return;
      const rank = (t.rank || t.rating || 1);
      map[name] = {
        name,
        tier: t.tier || 1,
        rank
      };
    });
    return map;
  }

  // --- Pyramid math (unchanged in spirit) ---

  get pyramidCounts() {
    const counts = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    this.purchasedTalents.forEach((t) => {
      const tier = t.tier || 1;
      if (counts[tier] === undefined) counts[tier] = 0;
      counts[tier] += 1;
    });
    return counts;
  }

  get tierSummary() {
    const c = this.pyramidCounts;
    return [5, 4, 3, 2, 1].map((tier) => ({
      tier,
      count: c[tier] || 0
    }));
  }

  get isBalanced() {
    const c = this.pyramidCounts;
    return (
      c[1] >= c[2] &&
      c[2] >= c[3] &&
      c[3] >= c[4] &&
      c[4] >= c[5]
    );
  }

  _pyramidOkIfAddTier(tier) {
    const base = this.pyramidCounts;
    const c = {
      1: base[1] || 0,
      2: base[2] || 0,
      3: base[3] || 0,
      4: base[4] || 0,
      5: base[5] || 0
    };

    if (c[tier] === undefined) c[tier] = 0;
    c[tier] += 1;

    return (
      c[1] >= c[2] &&
      c[2] >= c[3] &&
      c[3] >= c[4] &&
      c[4] >= c[5]
    );
  }

  // --- Tier grouping with row metadata ---

  get tierTabs() {
    const tiersPresent = new Set(
      this.availableTalents.map((t) => t.tier || 1)
    );
    const tiers = [1, 2, 3, 4, 5].filter((t) => tiersPresent.has(t));
    return tiers.length ? tiers : [1, 2, 3, 4, 5];
  }

  get talentsByTier() {
    const grouped = {};
    const current = this.currentTalentMap;

    this.availableTalents.forEach((t) => {
      const tier = t.tier || 1;
      if (!grouped[tier]) grouped[tier] = [];

      const name = t.name;
      const cur = current[name];
      const hasTalent   = !!cur;
      const currentRank = cur ? cur.rank : 0;
      const canAdd      = !hasTalent && this._pyramidOkIfAddTier(tier);

      // Format specializations as a comma-separated string
      let specializationsText = '';
      if (t.specializations && Array.isArray(t.specializations) && t.specializations.length > 0) {
        specializationsText = t.specializations.join(', ');
      }

      grouped[tier].push({
        name,
        tier,
        ranked: t.ranked,
        force_power: t.force_power,
        prereq: t.prereq,
        specializations: t.specializations,
        specializationsText: specializationsText,
        hasTalent,
        currentRank,
        canAdd
      });
    });

    Object.keys(grouped).forEach((k) => {
      grouped[k].sort((a, b) => (a.name || '').localeCompare(b.name || ''));
    });

    return grouped;
  }

  get activeTierTalents() {
    const byTier = this.talentsByTier;
    return byTier[this.activeTier] || [];
  }

  // --- Helpers to sync localTalents <-> @char.talents ---

  _setTalents(newList) {
    this.localTalents = newList;
    // Mirror into the char object so it gets sent back in chargen JSON.
    if (this.args.char) {
      this.args.char.talents = newList;
    }
    if (this.args.updated) {
      this.args.updated();  // let chargen page know something changed
    }
  }

  // --- Actions ---

  @action
  selectTier(tier) {
    this.activeTier = tier;
  }

  @action
  addTalentFromRow(row) {
    if (!row || !row.name) return;
    if (!row.canAdd) return;

    const currentMap = this.currentTalentMap;
    const list = this.purchasedTalents.slice(0);
    const existing = currentMap[row.name];

    if (existing && row.ranked) {
      // Increase rank on an existing ranked talent.
      const idx = list.findIndex((t) => t.name === row.name);
      if (idx >= 0) {
        const old = list[idx];
        const newRank = (old.rank || old.rating || 1) + 1;
        list[idx] = {
          ...old,
          rank:   newRank,
          rating: newRank
        };
      }
    } else if (!existing) {
      // Add a new talent.
      list.push({
        name: row.name,
        tier: row.tier,
        ranked: row.ranked,
        rank: row.ranked ? 1 : null,
        rating: row.ranked ? 1 : 1,
        specialization: null
      });
    }

    this._setTalents(list);
  }

  @action
  removeTalentFromRow(row) {
    if (!row || !row.name) return;

    const list = this.purchasedTalents.filter((t) => t.name !== row.name);
    this._setTalents(list);
  }
}