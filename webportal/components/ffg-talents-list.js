import Component from '@glimmer/component';
import { action } from '@ember/object';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';
import { A } from '@ember/array';
// Utility functions copied from server-side rules. We keep them here inside
// the talents component rather than creating a `webportal/utils` directory
// to avoid adding unsupported folders to the core project.

function ratingPlusTier(t) {
  if (!t) return 0;
  return (t.rank ? (t.tier + t.rank - 1) : t.tier);
}

function talentTreeBalancedForAdd(talents, tier) {
  if (tier === 1) return true;
  const priorTier = talents.filter(t => t.tier === (tier - 1) || (t.rank && ratingPlusTier(t) >= (tier - 1)));
  const currentTier = talents.filter(t => t.tier === tier || (t.rank && ratingPlusTier(t) >= tier));
  return (priorTier.length > currentTier.length + 1);
}

function talentTreeBalancedForRemove(talents, tier) {
  if (!talents || talents.length === 1) return true;
  if (!tier) return true;
  if (tier === 5) return true;

  const nextTier = talents.filter(t => t.tier === (tier + 1) || (t.rank && ratingPlusTier(t) >= (tier + 1)));
  const currentTier = talents.filter(t => t.tier === tier || (t.rank && ratingPlusTier(t) >= tier));

  return (currentTier.length - 1) >= (nextTier.length === 0 ? 0 : (nextTier.length + 1));
}

export default class FfgTalentsListComponent extends Component {
  @service gameApi;
  @service flashMessages;

  @tracked selectedTalent = null;

  get pyramidTiers() {
    return [5,4,3,2,1];
  }

  get availableTalents() {
    // Pull the full talent config from cgInfo if present, else empty.
    return (this.args.cgInfo && this.args.cgInfo.talents) ? this.args.cgInfo.talents : [];
  }

  talentsForTier(tier) {
    let talents = (this.args.char && this.args.char.talents) ? this.args.char.talents: [];
    return talents.filter(t => t.tier === tier).length;
  }

  specList(talent) {
    const specs = talent.specializations || talent.specializations || talent['specializations'] || [];
    return Array.isArray(specs) ? specs.join(', ') : (specs || '');
  }

  @action
  onSelect(evt) {
    this.selectedTalent = evt.target.value;
  }

  @action
  onTextInput(evt) {
    this.selectedTalent = evt.target.value;
  }

  @action
  async addSelected() {
    if (!this.selectedTalent) return;
    await this.addTalent(this.selectedTalent);
    this.selectedTalent = null;
  }

  @action
  async addTalent(name) {
    // Defensive: check config/availability
    const config = this.availableTalents.find(t => t['name'] === name);
    if (!config) return;

    // Check force user restriction
    if (config['force_power'] && !(this.args.cgInfo && this.args.cgInfo.use_force)) {
      // Show flash message if available
      if (this.flashMessages) this.flashMessages.error('Only force users can select this talent');
      return;
    }

    // Check prereq
    if (config['prereq']) {
      let have = (this.args.char && this.args.char.talents) ? this.args.char.talents.some(t => t.name.toLowerCase() === (config['prereq'] || '').toLowerCase()) : false;
      if (!have) {
        if (this.flashMessages) this.flashMessages.error(`Missing prerequisite: ${config['prereq']}`);
        return;
      }
    }

    // Client-side pyramid check
    const tier = config['tier'] || 1;
    if (!talentTreeBalancedForAdd(this.args.char.talents || [], tier)) {
      if (this.flashMessages) this.flashMessages.error('Adding that talent would unbalance your talent tree.');
      return;
    }

    // If parent provided a handler, use it; the parent will call server.
    if (this.args.addTalent) {
      await this.args.addTalent(name);
      return;
    }

    // Fallback: call gameApi directly with a simple command.
    if (this.gameApi && this.gameApi.sendCommand) {
      this.gameApi.sendCommand(`talent add ${name}`);
    } else if (this.gameApi && this.gameApi.request) {
      await this.gameApi.request('/cmd/talent/add', { name: name });
    }

    if (this.args.updated) this.args.updated();
  }

  @action
  async removeTalent(name) {
    const talent = (this.args.char && this.args.char.talents) ? this.args.char.talents.find(t => t.name === name) : null;
    const tier = talent && talent.rank ? (talent.tier + talent.rank -1) : (talent ? talent.tier : null);

    if (!talent) return;

    if (!talentTreeBalancedForRemove(this.args.char.talents || [], tier)) {
      if (this.flashMessages) this.flashMessages.error('Removing that talent would unbalance your talent tree.');
      return;
    }

    if (this.args.removeTalent) {
      await this.args.removeTalent(name);
      return;
    }

    if (this.gameApi && this.gameApi.sendCommand) {
      this.gameApi.sendCommand(`talent remove ${name}`);
    } else if (this.gameApi && this.gameApi.request) {
      await this.gameApi.request('/cmd/talent/remove', { name: name });
    }

    if (this.args.updated) this.args.updated();
  }
}
