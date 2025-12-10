import Component from '@ember/component';
import { inject as service } from '@ember/service';
import { action } from '@ember/object';

export default Component.extend({
  gameApi: service(),
  flashMessages: service(),
  tagName: '',

  selectedSkill: null,
  rollModifiers: null,

  @action
  cancelAddRoll() {
    this.set('selectAddRoll', false);
    this.set('selectedSkill', null);
    this.set('rollModifiers', null);
  },

  @action
  addRoll() {
    let api = this.gameApi;
    let selectedSkill = this.selectedSkill;
    let rollModifiers = this.rollModifiers;

    // Build roll string
    let rollString = '';

    if (selectedSkill) {
      rollString = selectedSkill;
      if (rollModifiers) {
        rollString += ' ' + rollModifiers;
      }
    } else if (rollModifiers) {
      rollString = rollModifiers;
    } else {
      this.flashMessages.danger("You must select a skill or enter a custom roll string.");
      return;
    }

    var sender;
    if (this.scene) {
      sender = this.get('scene.poseChar.name');
    }

    this.set('selectAddRoll', false);
    this.set('selectedSkill', null);
    this.set('rollModifiers', null);

    var destinationId, command;
    if (this.destinationType == 'scene') {
      destinationId = this.get('scene.id');
      command = 'addSceneRoll';
    } else {
      destinationId = this.get('job.id');
      command = 'addJobRoll';
    }

    api.requestOne(command, {
      id: destinationId,
      roll_string: rollString,
      sender: sender
    }, null)
    .then((response) => {
      if (response.error) {
        return;
      }
    });
  }
});
