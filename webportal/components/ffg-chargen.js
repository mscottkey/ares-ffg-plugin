import Component from '@ember/component';
import { inject as service } from '@ember/service';
import { computed } from '@ember/object';

export default Component.extend({
  tagName: '',
  flashMessages: service(),
  gameApi: service(),
  selectedSpecName: null,

  didInsertElement() {
    this._super(...arguments);
    let self = this;
    this.set('updateCallback', function() { return self.onUpdate(); });
  },

  onUpdate() {
    if (this.updated) {
      this.updated();
    }
  },

  // Filter available specializations
  availableSpecs: computed('cgInfo.specializations', 'char.career.name', 'char.specializations.@each.name', function() {
    let allSpecs = this.get('cgInfo.specializations') || [];
    let careerName = this.get('char.career.name');
    let currentSpecs = (this.get('char.specializations') || []).map(s => s.name);
    
    return allSpecs.filter(spec => {
      if (currentSpecs.includes(spec.name)) {
        return false;
      }
      return !spec.career || spec.career === careerName;
    });
  }),

  // Calculate spent XP
  spentXP: computed('char.starting_xp', 'char.current_xp', function() {
    let starting = this.get('char.starting_xp') || 0;
    let current = this.get('char.current_xp') || 0;
    return starting - current;
  }),

  actions: {
    abilityChanged() {
      this.onUpdate();
    },

    selectArchetype(event) {
      let archetype = event.target.value;
      if (!archetype) { return; }

      let name = this.get('name');
      if (!name) { return; }

      this.get('gameApi').requestOne('setFFGArchetype', {
        id: name,
        archetype: archetype
      }).then((response) => {
        if (response.error) {
          this.get('flashMessages').danger(response.error);
          return;
        }

        if (response.char) {
          this.set('char', response.char);
          this.onUpdate();
        }
      });
    },

    selectCareer(event) {
      let career = event.target.value;
      if (!career) { return; }

      let name = this.get('name');
      if (!name) { return; }

      this.get('gameApi').requestOne('setFFGCareer', {
        id: name,
        career: career
      }).then((response) => {
        if (response.error) {
          this.get('flashMessages').danger(response.error);
          return;
        }

        if (response.char) {
          this.set('char', response.char);
          this.onUpdate();
        }
      });
    },

    updateSpecSelection(event) {
      this.set('selectedSpecName', event.target.value);
    },

    addSpecialization() {
      let specialization = this.get('selectedSpecName');
      if (!specialization) { return; }

      let name = this.get('name');
      if (!name) { return; }

      this.get('gameApi').requestOne('addFFGSpecialization', {
        id: name,
        specialization: specialization
      }).then((response) => {
        if (response.error) {
          this.get('flashMessages').danger(response.error);
          return;
        }

        if (response.char) {
          this.set('char', response.char);
          this.set('selectedSpecName', null);
          this.onUpdate();
        }
      });
    },

    removeSpecialization(specName) {
      if (!confirm(`Remove specialization: ${specName}?`)) {
        return;
      }

      let name = this.get('name');
      if (!name) { return; }

      this.get('gameApi').requestOne('removeFFGSpecialization', {
        id: name,
        specialization: specName
      }).then((response) => {
        if (response.error) {
          this.get('flashMessages').danger(response.error);
          return;
        }

        if (response.char) {
          this.set('char', response.char);
          this.onUpdate();
        }
      });
    }
  }
});