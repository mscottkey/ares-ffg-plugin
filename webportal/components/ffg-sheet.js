import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';

export default class FfgSheetComponent extends Component {

  get woundPercentage() {
    if (!this.args.char.custom.ffg || !this.args.char.custom.ffg.wounds) {
      return 0;
    }
    const current = this.args.char.custom.ffg.wounds.current || 0;
    const max = this.args.char.custom.ffg.wounds.max || 1;
    return Math.round((current / max) * 100);
  }

  get strainPercentage() {
    if (!this.args.char.custom.ffg || !this.args.char.custom.ffg.strain) {
      return 0;
    }
    const current = this.args.char.custom.ffg.strain.current || 0;
    const max = this.args.char.custom.ffg.strain.max || 1;
    return Math.round((current / max) * 100);
  }

  get talentsByTier() {
    if (!this.args.char.custom.ffg || !this.args.char.custom.ffg.talents) {
      return null;
    }

    const talents = this.args.char.custom.ffg.talents;
    if (talents.length === 0) {
      return null;
    }

    // Group talents by tier
    const tierGroups = {};
    talents.forEach(talent => {
      const tier = talent.tier || 1;
      if (!tierGroups[tier]) {
        tierGroups[tier] = [];
      }
      tierGroups[tier].push(talent);
    });

    // Convert to sorted array
    return Object.keys(tierGroups)
      .sort((a, b) => parseInt(a) - parseInt(b))
      .map(tier => ({
        tier: tier,
        talents: tierGroups[tier]
      }));
  }

  groupUpgrades(upgrades) {
    if (!upgrades || upgrades.length === 0) {
      return [];
    }

    // Count occurrences of each upgrade
    const upgradeCounts = {};
    upgrades.forEach(upgrade => {
      if (!upgradeCounts[upgrade]) {
        upgradeCounts[upgrade] = 0;
      }
      upgradeCounts[upgrade]++;
    });

    // Convert to array with counts
    return Object.keys(upgradeCounts).map(name => ({
      name: name,
      count: upgradeCounts[name]
    })).sort((a, b) => a.name.localeCompare(b.name));
  }
}
