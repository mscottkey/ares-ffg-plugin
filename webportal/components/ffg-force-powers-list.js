import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';

export default class FfgForcePowersListComponent extends Component {
  @tracked showingUpgradesFor = null;

  get selectedPowers() {
    const powers = this.args.char.force_powers || [];
    const allPowers = this.args.cgInfo.force_powers || [];

    return powers.map(p => {
      const config = allPowers.find(cp => cp.name === p.name);
      if (!config) return null;

      // Group upgrades with counts
      const upgradeCounts = {};
      (p.upgrades || []).forEach(u => {
        upgradeCounts[u] = (upgradeCounts[u] || 0) + 1;
      });

      const selectedUpgrades = Object.keys(upgradeCounts).map(name => ({
        name: name,
        count: upgradeCounts[name]
      }));

      return {
        name: p.name,
        description: config.description,
        base_xp_cost: config.base_xp_cost || 10,
        upgrades: config.upgrades || [],
        selectedUpgrades: selectedUpgrades
      };
    }).filter(p => p !== null);
  }

  get availablePowers() {
    const allPowers = this.args.cgInfo.force_powers || [];
    const selected = (this.args.char.force_powers || []).map(p => p.name);

    return allPowers.filter(p => !selected.includes(p.name));
  }

  get selectedPowersCount() {
    return this.selectedPowers.length;
  }

  get totalPowers() {
    return (this.args.cgInfo.force_powers || []).length;
  }

  get totalXPCost() {
    let cost = 0;

    this.selectedPowers.forEach(power => {
      // Base power cost
      cost += power.base_xp_cost;

      // Upgrade costs
      power.selectedUpgrades.forEach(upgrade => {
        const upgradeConfig = power.upgrades.find(u => u.name === upgrade.name);
        if (upgradeConfig) {
          const upgradeCost = upgradeConfig.xp_cost || 5;
          cost += upgradeCost * upgrade.count;
        }
      });
    });

    return cost;
  }

  get currentPowerUpgrades() {
    if (!this.showingUpgradesFor) return [];

    const power = this.selectedPowers.find(p => p.name === this.showingUpgradesFor);
    if (!power) return [];

    const charPower = (this.args.char.force_powers || []).find(p => p.name === this.showingUpgradesFor);
    const currentUpgrades = charPower ? (charPower.upgrades || []) : [];

    // Count current upgrades
    const upgradeCounts = {};
    currentUpgrades.forEach(u => {
      upgradeCounts[u] = (upgradeCounts[u] || 0) + 1;
    });

    return power.upgrades.map(u => ({
      name: u.name,
      description: u.description,
      xp_cost: u.xp_cost || 5,
      max_rank: u.max_rank || 1,
      prereq: u.prereq || null,
      current: upgradeCounts[u.name] || 0
    }));
  }

  @action
  addPower(powerName) {
    const powers = [...(this.args.char.force_powers || [])];
    powers.push({ name: powerName, upgrades: [] });

    this.updatePowers(powers);
  }

  @action
  removePower(powerName) {
    const powers = (this.args.char.force_powers || []).filter(p => p.name !== powerName);
    this.updatePowers(powers);
  }

  @action
  manageUpgrades(powerName) {
    this.showingUpgradesFor = powerName;
  }

  @action
  closeUpgrades() {
    this.showingUpgradesFor = null;
  }

  @action
  increaseUpgrade(upgradeName) {
    const powers = [...(this.args.char.force_powers || [])];
    const power = powers.find(p => p.name === this.showingUpgradesFor);

    if (power) {
      power.upgrades = [...(power.upgrades || []), upgradeName];
      this.updatePowers(powers);
    }
  }

  @action
  decreaseUpgrade(upgradeName) {
    const powers = [...(this.args.char.force_powers || [])];
    const power = powers.find(p => p.name === this.showingUpgradesFor);

    if (power) {
      const index = power.upgrades.indexOf(upgradeName);
      if (index > -1) {
        power.upgrades = [...power.upgrades];
        power.upgrades.splice(index, 1);
        this.updatePowers(powers);
      }
    }
  }

  updatePowers(powers) {
    // Update the character's force_powers array
    this.args.char.force_powers = powers;

    // Notify parent of change
    if (this.args.updated) {
      this.args.updated();
    }
  }
}
