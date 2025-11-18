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
    this.validateChar();
  },

  // Hook that core chargen can call if needed; no-op for now.
  onUpdate() {
    // Intentionally empty - we just keep this for compatibility.
  },

  validateChar() {
    let errors = A();

    // Safely walk down the char -> custom -> ffg structure.
    let char   = this.get('char') || {};
    let custom = char.custom || {};
    let ffg    = custom.ffg || {};
    let cgInfo = custom.cg_ffg || {};

    let characteristics   = ffg.characteristics || [];
    let skills            = ffg.skills || [];
    let careerSkillNames  = ffg.career_skills || [];

    let maxChar          = cgInfo.max_cg_characteristic_rating || 5;
    let maxSkill         = cgInfo.max_cg_skill_rating || 2;
    let minCareerSkills  = cgInfo.min_career_skills || 0;

    // --- Characteristic caps ---
    characteristics.forEach(c => {
      let rating = c.rating || 0;
      if (rating > maxChar) {
        errors.pushObject(
          `${c.name} is above the maximum chargen characteristic (${maxChar}).`
        );
      }
    });

    // --- Skill caps ---
    skills.forEach(s => {
      let rating = s.rating || 0;
      if (rating > maxSkill) {
        errors.pushObject(
          `${s.name} is above the maximum chargen skill (${maxSkill}).`
        );
      }
    });

    // --- Career skill minimum ---
    if (minCareerSkills > 0 && careerSkillNames.length > 0) {
      let taken = skills.filter(s => {
        let rating = s.rating || 0;
        // indexOf for compatibility
        return rating > 0 && careerSkillNames.indexOf(s.name) >= 0;
      }).length;

      if (taken < minCareerSkills) {
        errors.pushObject(
          `You must take at least ${minCareerSkills} career skills; you currently have ${taken}.`
        );
      }
    }

    this.set('charErrors', errors);
  },

  actions: {
    abilityChanged() {
      this.validateChar();

      // Let core chargen know something changed so it can recalc state.
      if (this.updateCallback) {
        this.updateCallback();
      }
    }
  }
});
