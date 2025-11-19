import Component from '@ember/component';
import { inject as service } from '@ember/service';
import { A } from '@ember/array';

export default Component.extend({
  tagName: '',
  flashMessages: service(),
  gameApi: service(),

  didInsertElement() {
    this._super(...arguments);
    let self = this;
    this.set('updateCallback', function() { return self.onUpdate(); });
    
    // IMPORTANT: Initialize custom.ffg if it doesn't exist
    if (!this.get('char.custom')) {
      this.set('char.custom', {});
    }
    if (!this.get('char.custom.ffg')) {
      this.set('char.custom.ffg', this.get('char.custom.ffg') || {});
    }
    
    this.validateChar();
  },

  onUpdate() {
    this.validateChar();
  },

  validateChar() {
    let errors = A();
    let char = this.get('char.custom.ffg') || {};
    let cgInfo = this.get('char.custom.cg_ffg') || {};

    let characteristics = char.characteristics || [];
    let skills = char.skills || [];
    let careerSkills = char.career_skills || [];
    let archetype = char.archetype;
    let career = char.career;

    let maxChar = cgInfo.max_cg_characteristic_rating || 5;
    let maxSkill = cgInfo.max_cg_skill_rating || 2;
    let minCareerSkills = cgInfo.min_career_skills || 4;

    // Characteristic validation
    characteristics.forEach(c => {
      let rating = c.rating || 0;
      if (rating > maxChar) {
        errors.pushObject(
          `${c.name} is above the maximum chargen characteristic (${maxChar}).`
        );
      }
    });

    // Skill validation
    skills.forEach(s => {
      let rating = s.rating || 0;
      if (rating > maxSkill) {
        errors.pushObject(
          `${s.name} is above the maximum chargen skill (${maxSkill}).`
        );
      }
    });

    // Career skill minimum
    if (minCareerSkills > 0 && careerSkills.length > 0) {
      let taken = skills.filter(s => {
        let rating = s.rating || 0;
        return rating > 0 && careerSkills.includes(s.name);
      }).length;

      if (taken < minCareerSkills) {
        errors.pushObject(
          `You must take at least ${minCareerSkills} career skills; you currently have ${taken}.`
        );
      }
    }

    // Archetype required
    if (cgInfo.archetypes && cgInfo.archetypes.length > 0) {
      if (!archetype || !archetype.name) {
        errors.pushObject('You must choose an archetype.');
      }
    }

    // Career required
    if (cgInfo.careers && cgInfo.careers.length > 0) {
      if (!career || !career.name) {
        errors.pushObject('You must choose a career.');
      }
    }

    this.set('charErrors', errors);
  },

  actions: {
    abilityChanged() {
      this.validateChar();
      if (this.updateCallback) {
        this.updateCallback();
      }
    }
  }
});