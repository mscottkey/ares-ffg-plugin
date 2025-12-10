import Component from '@ember/component';
import { inject as service } from '@ember/service';
import { action } from '@ember/object';

export default Component.extend({
  gameApi: service(),
  flashMessages: service(),
  tagName: '',

  yourSkill: null,
  yourModifiers: null,
  opponentName: null,
  opponentSkill: null,

  @action
  cancelAddOpposed() {
    this.set('selectAddOpposed', false);
    this.set('yourSkill', null);
    this.set('yourModifiers', null);
    this.set('opponentName', null);
    this.set('opponentSkill', null);
  },

  @action
  addOpposedRoll() {
    let api = this.gameApi;
    let yourSkill = this.yourSkill;
    let yourModifiers = this.yourModifiers;
    let opponentName = this.opponentName;
    let opponentSkill = this.opponentSkill;

    if (!yourSkill) {
      this.flashMessages.danger("You must specify your skill.");
      return;
    }

    if (!opponentName || !opponentSkill) {
      this.flashMessages.danger("You must specify the opponent's name and skill.");
      return;
    }

    // Build roll string: "Skill+modifiers vs Name/Skill"
    let rollString = yourSkill;
    if (yourModifiers) {
      rollString += ' ' + yourModifiers;
    }
    rollString += ' vs ' + opponentName + '/' + opponentSkill;

    var sender;
    if (this.scene) {
      sender = this.get('scene.poseChar.name');
    }

    this.set('selectAddOpposed', false);
    this.set('yourSkill', null);
    this.set('yourModifiers', null);
    this.set('opponentName', null);
    this.set('opponentSkill', null);

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
