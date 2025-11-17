import EmberObject, { computed } from '@ember/object';
import { A } from '@ember/array';
import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  flashMessages: service(),
  gameApi: service(),

  didInsertElement() {
    this._super(...arguments);
    let self = this;
    this.set('updateCallback', function() { return self.onUpdate(); });
  },

  onUpdate() {
    return {
      characteristics: this.createSimpleHash(this.get('char.custom.ffg.characteristics')),
      skills: this.createSimpleHash(this.get('char.custom.ffg.skills')),
      talents: this.createTalentHash(this.get('char.custom.ffg.talents'))
    };
  },

  // For characteristics or skills, which are simple "name: rating"
  createSimpleHash(list) {
    if (!list) return {};
    return list.reduce((map, obj) => {
      if (obj.name && obj.name.length > 0) {
        map[obj.name] = obj.rating;
      }
      return map;
    }, {});
  },

  // For talents, which in FFG have name + rank (sometimes)
  createTalentHash(list) {
    if (!list) return {};
    return list.reduce((map, obj) => {
      if (obj.name && obj.name.length > 0) {
        let value = obj.rank ? obj.rank.toString() : "0";
        map[obj.name] = value;
      }
      return map;
    }, {});
  },

  validateChar() {
    this.set('charErrors', A());
  },

  actions: {
    abilityChanged() {
      this.validateChar();
    }
  }
});
