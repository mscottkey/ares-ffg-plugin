import EmberObject, { computed } from '@ember/object';
import { A } from '@ember/array';
import Component from '@ember/component';
import { inject as service } from '@ember/service';

export default Component.extend({
  tagName: '',
  flashMessages: service(),
  gameApi: service(),
  
  didInsertElement: function() {
    this._super(...arguments);
    let self = this;
    this.set('updateCallback', function() { return self.onUpdate(); } );
  },
  
  onUpdate: function() {
    // This returns the data structure that will be saved
    // It should return PLAIN objects, not Ember objects with getters/setters
    let ffg = this.get('char.custom.ffg') || {};
    
    return {
      ffg: {
        archetype: ffg.archetype ? {
          name: ffg.archetype.name,
          characteristics: ffg.archetype.characteristics,
          wound: ffg.archetype.wound,
          strain: ffg.archetype.strain,
          xp: ffg.archetype.xp
        } : null,
        career: ffg.career ? {
          name: ffg.career.name,
          career_skills: ffg.career.career_skills || []
        } : null,
        career_skills: ffg.career_skills || [],
        specializations: (ffg.specializations || []).map(s => ({
          name: s.name,
          career: s.career,
          career_skills: s.career_skills || [],
          force_user: s.force_user
        })),
        characteristics: (ffg.characteristics || []).map(c => ({
          name: c.name,
          desc: c.desc,
          rating: c.rating || 0
        })),
        skills: (ffg.skills || []).map(s => ({
          name: s.name,
          desc: s.desc,
          characteristic: s.characteristic,
          rating: s.rating || 0,
          is_career: s.is_career
        })),
        talents: (ffg.talents || []).map(t => ({
          name: t.name,
          rank: t.rank,
          tier: t.tier,
          specialization: t.specialization
        })),
        starting_xp: ffg.starting_xp,
        current_xp: ffg.current_xp,
        wounds: ffg.wounds,
        strain: ffg.strain
      }
    };
  },
  
  validateChar: function() {
    let errors = A();
    let ffg = this.get('char.custom.ffg') || {};
    let cgInfo = this.get('char.custom.cg_ffg') || {};

    let characteristics = ffg.characteristics || [];
    let skills = ffg.skills || [];
    let careerSkills = ffg.career_skills || [];
    let archetype = ffg.archetype;
    let career = ffg.career;

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
    }
  }
});