import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { inject as service } from '@ember/service';
import { action } from '@ember/object';

export default class FfgRollSpendsComponent extends Component {
  @service gameApi;
  @service flashMessages;

  @tracked rolls = [];
  @tracked loading = false;
  @tracked selectedRollId = null;
  @tracked selectedSpend = null;
  @tracked targetName = null;

  constructor() {
    super(...arguments);
    this.loadSpends();
  }

  get selectedRoll() {
    return this.rolls.find(r => r.id === this.selectedRollId);
  }

  get availableSpends() {
    return this.selectedRoll ? (this.selectedRoll.spends || []) : [];
  }

  get needsTarget() {
    const spend = this.availableSpends.find(s => s.name === this.selectedSpend);
    return spend ? spend.target === 'other' : false;
  }

  get hasRolls() {
    return this.rolls.length > 0;
  }

  @action
  loadSpends() {
    this.loading = true;

    this.gameApi.requestOne('getRollSpends', {}, null)
    .then((response) => {
      this.loading = false;

      if (response.error) {
        return;
      }

      this.rolls = response.rolls || [];

      if (!this.selectedRoll && this.rolls.length) {
        this.selectedRollId = this.rolls[0].id;
      }
    });
  }

  @action
  selectRoll(event) {
    this.selectedRollId = event.target.value;
    this.selectedSpend = null;
  }

  @action
  selectSpend(event) {
    this.selectedSpend = event.target.value;
  }

  @action
  updateTarget(event) {
    this.targetName = event.target.value;
  }

  @action
  cancelSpend() {
    this.selectedSpend = null;
    this.targetName = null;

    if (this.args.onClose) {
      this.args.onClose();
    }
  }

  @action
  applySpend() {
    if (!this.selectedRollId || !this.selectedSpend) {
      this.flashMessages.danger('You must pick a roll and a spend.');
      return;
    }

    if (this.needsTarget && !this.targetName) {
      this.flashMessages.danger('That spend needs a target.');
      return;
    }

    this.gameApi.requestOne('applyRollSpend', {
      roll_id: this.selectedRollId,
      spend: this.selectedSpend,
      target: this.targetName
    }, null)
    .then((response) => {
      if (response.error) {
        return;
      }

      this.flashMessages.success(response.message);
      this.selectedSpend = null;
      this.targetName = null;

      // Reload so symbols the spend consumed drop out of the menu.
      this.loadSpends();
    });
  }
}
