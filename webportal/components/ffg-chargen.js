import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  gameApi: service(),
  flashMessages: service(),

  // For specialization add flow.
  selectedSpecName: null,

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
    // ----- EXISTING ACTIONS -----

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
    },

    // ----- NEW ACTIONS FOR ARCHETYPE/CAREER/SPECS -----

    selectArchetype(event) {
      let archetype = event.target.value;
      if (!archetype) { return; }

      let char = this.get('char');
      if (!char) { return; }

      this.get('gameApi').requestOne('setFFGArchetype', {
        id: char.id,
        archetype: archetype
      }).then((response) => {
        if (!response) { return; }

        if (response.error) {
          this.get('flashMessages')?.danger(response.error);
          return;
        }

        // Adjust this depending on how your handler responds.
        if (response.char) {
          this.set('char', response.char);
        } else if (response.custom) {
          char.custom = response.custom;
          this.set('char', char);
        }

        this._notifyUpdated();
      });
    },

    selectCareer(event) {
      let career = event.target.value;
      if (!career) { return; }

      let char = this.get('char');
      if (!char) { return; }

      this.get('gameApi').requestOne('setFFGCareer', {
        id: char.id,
        career: career
      }).then((response) => {
        if (!response) { return; }

        if (response.error) {
          this.get('flashMessages')?.danger(response.error);
          return;
        }

        if (response.char) {
          this.set('char', response.char);
        } else if (response.custom) {
          char.custom = response.custom;
          this.set('char', char);
        }

        this._notifyUpdated();
      });
    },

    updateSpecSelection(event) {
      this.set('selectedSpecName', event.target.value);
    },

    addSpecialization() {
      let specialization = this.get('selectedSpecName');
      if (!specialization) { return; }

      let char = this.get('char');
      if (!char) { return; }

      this.get('gameApi').requestOne('addFFGSpecialization', {
        id: char.id,
        specialization: specialization
      }).then((response) => {
        if (!response) { return; }

        if (response.error) {
          this.get('flashMessages')?.danger(response.error);
          return;
        }

        if (response.char) {
          this.set('char', response.char);
        } else if (response.custom) {
          char.custom = response.custom;
          this.set('char', char);
        }

        this._notifyUpdated();
      });
    }
  }
});
