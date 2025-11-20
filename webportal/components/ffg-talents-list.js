import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { set } from '@ember/object';

export default class FfgTalentsListComponent extends Component {
  @tracked activeTier = 1;
  @tracked localTalents = null;

  // --- Base data ---

  get char() {
    return this.args.char || {};
  }

  get cgInfo() {
    return this.args.cgInfo || {};
  }

  // Track specializations separately to ensure reactivity
  get characterSpecs() {
    return (this.char.specializations || []).map(s => s.name);
  }

  get isForceUser() {
    return (this.char.specializations || []).some(s => s.force_user);
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

  // --- Pyramid math ---

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
    return [1, 2, 3, 4, 5].map((tier) => ({
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
    
    // Use reactive getters to ensure updates when specializations change
    const charSpecs = this.characterSpecs;
    const isForceUser = this.isForceUser;
    
    // Also check if talents have changed to trigger recalculation
    const currentTalents = this.purchasedTalents;

    this.availableTalents.forEach((t) => {
      const tier = t.tier || 1;
      if (!grouped[tier]) grouped[tier] = [];

      const name = t.name;
      const cur = current[name];
      const hasTalent   = !!cur;
      const currentRank = cur ? cur.rank : 0;
      
      // Check if talent is available to this character
      let isAvailable = true;
      let unavailableReason = '';
      
      // Check force user requirement
      if (t.force_power && !isForceUser) {
        isAvailable = false;
        unavailableReason = 'Requires Force User specialization';
      }
      
      // Check specialization requirement
      if (isAvailable && t.specializations && t.specializations.length > 0) {
        const hasRequiredSpec = t.specializations.some(spec => charSpecs.includes(spec));
        if (!hasRequiredSpec) {
          isAvailable = false;
          unavailableReason = `Requires specialization: ${t.specializations.join(' or ')}`;
        }
      }
      
      // Check prerequisite talent
      if (isAvailable && t.prereq) {
        const hasPrereq = !!current[t.prereq];
        if (!hasPrereq) {
          isAvailable = false;
          unavailableReason = `Requires prerequisite: ${t.prereq}`;
        }
      }
      
      // Check if can add based on pyramid balance
      const canAdd = isAvailable && !hasTalent && this._pyramidOkIfAddTier(tier);

      // Format specializations as a comma-separated string
      let specializationsText = '';
      if (t.specializations && Array.isArray(t.specializations) && t.specializations.length > 0) {
        specializationsText = t.specializations.join(', ');
      }

      // Only include available talents or talents the character already has
      if (isAvailable || hasTalent) {
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
          canAdd,
          isAvailable,
          unavailableReason
        });
      }
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
    this.localTalents = [...newList]; // Create a new array to trigger reactivity
    
    // Mirror into the char object so it gets sent back in chargen JSON.
    if (this.args.char) {
      // Use set from @ember/object to properly notify Ember of the change
      set(this.args.char, 'talents', [...newList]);
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