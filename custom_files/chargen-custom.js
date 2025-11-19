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

    // NEW: current selections (will be filled once backend supports them)
    let archetype         = ffg.archetype || null;
    let career            = ffg.career || null;
    let specializations   = ffg.specializations || [];

    // NEW: option lists from YAML (once exposed in cg_ffg)
    let archetypeOptions  = cgInfo.archetypes || [];
    let careerOptions     = cgInfo.careers || [];
    let specOptions       = cgInfo.specializations || [];

    // Optional future config for specs; safe default if not present.
    let minSpecializations = cgInfo.min_specializations || 0;

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

    // --- Archetype required (if game defines archetypes) ---
    // Only enforce if we actually have archetype options configured.
    if (archetypeOptions.length > 0) {
      if (!archetype || !archetype.name) {
        errors.pushObject(
          'You must choose an archetype / species.'
        );
      }
    }

    // --- Career required (if game defines careers) ---
    if (careerOptions.length > 0) {
      if (!career || !career.name) {
        errors.pushObject(
          'You must choose a career.'
        );
      }
    }

    // --- Specializations minimum (optional, only if you later configure it) ---
    if (specOptions.length > 0 && minSpecializations > 0) {
      if (specializations.length < minSpecializations) {
        errors.pushObject(
          `You must choose at least ${minSpecializations} specialization${minSpecializations === 1 ? '' : 's'}.`
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
