import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  gameApi: service(),

  _maxChar() {
    let info = this.get('cgInfo') || {};
    return info.max_cg_characteristic_rating || 5;
  },

  _maxSkill() {
    let info = this.get('cgInfo') || {};
    return info.max_cg_skill_rating || 2;
  },

  _notifyUpdated() {
    // Call the parent-provided callback so chargen-custom can revalidate.
    let updated = this.get('updated');
    if (updated) {
      updated();
    }
  },

  actions: {
    changeCharacteristic(row, delta) {
      if (!row) { return; }

      let maxChar = this._maxChar();
      let current = row.rating || 0;
      let next = current + delta;

      if (next < 0) {
        next = 0;
      }
      if (next > maxChar) {
        next = maxChar;
      }

      // Mutate in place – these objects come from @char.characteristics
      row.rating = next;

      this._notifyUpdated();
    },

    changeSkill(row, delta) {
      if (!row) { return; }

      let maxSkill = this._maxSkill();
      let current = row.rating || 0;
      let next = current + delta;

      if (next < 0) {
        next = 0;
      }
      if (next > maxSkill) {
        next = maxSkill;
      }

      row.rating = next;

      this._notifyUpdated();
    },



    addTalent(name) {
      const gameApi = this.get('gameApi');
      if (gameApi && gameApi.sendCommand) {
        gameApi.sendCommand(`talent add ${name}`);
      } else if (gameApi && gameApi.request) {
        gameApi.request('/cmd/talent/add', { name }).catch(() => {});
      }
      this._notifyUpdated();
    },

    removeTalent(name) {
      const gameApi = this.get('gameApi');
      if (gameApi && gameApi.sendCommand) {
        gameApi.sendCommand(`talent remove ${name}`);
      } else if (gameApi && gameApi.request) {
        gameApi.request('/cmd/talent/remove', { name }).catch(() => {});
      }
      this._notifyUpdated();
    }
  }
});
