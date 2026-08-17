import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';
import { action } from '@ember/object';

export default class FfgCombatPanelComponent extends Component {
  @service gameApi;
  @service flashMessages;

  @tracked combat = null;
  @tracked loading = false;
  @tracked targetName = null;
  @tracked weapon = null;
  @tracked lastResult = null;

  constructor() {
    super(...arguments);
    this.loadCombat();
  }

  get hasCombat() {
    return !!this.combat;
  }

  get combatants() {
    return this.combat ? (this.combat.combatants || []) : [];
  }

  get weapons() {
    return this.combat ? (this.combat.weapons || []) : [];
  }

  // Anyone still standing other than the viewer is a legal target.
  get targets() {
    return this.combatants.filter(c => !c.incapacitated);
  }

  get isSuggestMode() {
    return this.combat ? this.combat.automation === 'suggest' : true;
  }

  @action
  loadCombat() {
    this.loading = true;

    this.gameApi.requestOne('getCombat', {}, null)
    .then((response) => {
      this.loading = false;

      if (response.error) {
        return;
      }

      this.combat = response.combat;
    });
  }

  @action
  selectTarget(event) {
    this.targetName = event.target.value;
  }

  @action
  selectWeapon(event) {
    this.weapon = event.target.value;
  }

  @action
  closePanel() {
    this.lastResult = null;

    if (this.args.onClose) {
      this.args.onClose();
    }
  }

  @action
  attack() {
    if (!this.targetName) {
      this.flashMessages.danger('You must pick a target.');
      return;
    }

    this.gameApi.requestOne('resolveAttack', {
      target: this.targetName,
      weapon: this.weapon
    }, null)
    .then((response) => {
      if (response.error) {
        return;
      }

      this.lastResult = response;
      this.combat = response.combat;
    });
  }
}
