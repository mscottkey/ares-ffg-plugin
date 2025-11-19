import Component from '@ember/component';
import { inject as service } from '@ember/service';
import { computed } from '@ember/object';
import { set } from '@ember/object';

export default Component.extend({
  tagName: '',
  flashMessages: service(),
  selectedSpecName: null,

  didInsertElement() {
    this._super(...arguments);
    let self = this;
    this.set('updateCallback', function() { return self.onUpdate(); });
  },

  // Get FFG data from char.custom.ffg
  ffgData: computed('char.custom.ffg', function() {
    return this.get('char.custom.ffg') || {};
  }),

  // Get chargen info from char.custom.cg_ffg
  cgInfo: computed('char.custom.cg_ffg', function() {
    return this.get('char.custom.cg_ffg') || {};
  }),

  onUpdate() {
    if (this.updated) {
      this.updated();
    }
  },

  // Filter available specializations
  availableSpecs: computed('cgInfo.specializations', 'ffgData.career.name', 'ffgData.specializations.@each.name', function() {
    let allSpecs = this.get('cgInfo.specializations') || [];
    let careerName = this.get('ffgData.career.name');
    let currentSpecs = (this.get('ffgData.specializations') || []).map(s => s.name);
    
    return allSpecs.filter(spec => {
      if (currentSpecs.includes(spec.name)) {
        return false;
      }
      return !spec.career || spec.career === careerName;
    });
  }),

  // Calculate spent XP
  spentXP: computed('ffgData.starting_xp', 'ffgData.current_xp', function() {
    let starting = this.get('ffgData.starting_xp') || 0;
    let current = this.get('ffgData.current_xp') || 0;
    return starting - current;
  }),

  actions: {
    abilityChanged() {
      this.onUpdate();
    },

    selectArchetype(event) {
      let archetypeName = event.target.value;
      if (!archetypeName) { return; }

      let cgInfo = this.get('cgInfo');
      let archetypes = cgInfo.archetypes || [];
      let archetype = archetypes.find(a => a.name === archetypeName);
      
      if (!archetype) { return; }

      let ffgData = this.get('ffgData');

      // Update the archetype
      set(ffgData, 'archetype', {
        name: archetype.name,
        characteristics: archetype.characteristics,
        wound: archetype.wound,
        strain: archetype.strain,
        xp: archetype.xp
      });

      // Reset characteristics to archetype defaults
      let characteristics = ffgData.characteristics || [];
      characteristics.forEach(c => {
        let archetypeValue = archetype.characteristics[c.name] || 0;
        set(c, 'rating', archetypeValue);
      });

      // Update XP
      let bonus_xp = cgInfo.bonus_xp || 0;
      let career_xp = cgInfo.career_skill_xp || 0;
      set(ffgData, 'starting_xp', archetype.xp + bonus_xp + career_xp);
      set(ffgData, 'current_xp', archetype.xp + bonus_xp + career_xp);

      this.onUpdate();
    },

    selectCareer(event) {
      let careerName = event.target.value;
      if (!careerName) { return; }

      let cgInfo = this.get('cgInfo');
      let careers = cgInfo.careers || [];
      let career = careers.find(c => c.name === careerName);
      
      if (!career) { return; }

      let ffgData = this.get('ffgData');

      // Update the career
      set(ffgData, 'career', {
        name: career.name,
        career_skills: career.career_skills || []
      });

      // Update career_skills list for validation
      set(ffgData, 'career_skills', career.career_skills || []);

      this.onUpdate();
    },

    updateSpecSelection(event) {
      this.set('selectedSpecName', event.target.value);
    },

    addSpecialization() {
      let specName = this.get('selectedSpecName');
      if (!specName) { return; }

      let cgInfo = this.get('cgInfo');
      let allSpecs = cgInfo.specializations || [];
      let specConfig = allSpecs.find(s => s.name === specName);
      
      if (!specConfig) { return; }

      let ffgData = this.get('ffgData');
      let specializations = ffgData.specializations || [];
      
      // Check if already have it
      if (specializations.find(s => s.name === specName)) {
        return;
      }

      // Add the specialization
      specializations.pushObject({
        name: specConfig.name,
        career: specConfig.career,
        career_skills: specConfig.career_skills || [],
        force_user: specConfig.force_user
      });

      // Update career_skills to include spec skills
      let careerSkills = ffgData.career_skills || [];
      let allCareerSkills = [...careerSkills];
      (specConfig.career_skills || []).forEach(skill => {
        if (!allCareerSkills.includes(skill)) {
          allCareerSkills.push(skill);
        }
      });
      set(ffgData, 'career_skills', allCareerSkills);

      // Update is_career flag on skills
      let skills = ffgData.skills || [];
      skills.forEach(skill => {
        set(skill, 'is_career', allCareerSkills.includes(skill.name));
      });

      this.set('selectedSpecName', null);
      this.onUpdate();
    },

    removeSpecialization(specName) {
      if (!confirm(`Remove specialization: ${specName}?`)) {
        return;
      }

      let ffgData = this.get('ffgData');
      let specializations = ffgData.specializations || [];
      let filtered = specializations.filter(s => s.name !== specName);
      set(ffgData, 'specializations', filtered);

      // Rebuild career_skills
      let careerSkills = ffgData.career && ffgData.career.career_skills ? ffgData.career.career_skills : [];
      let allCareerSkills = [...careerSkills];
      filtered.forEach(spec => {
        (spec.career_skills || []).forEach(skill => {
          if (!allCareerSkills.includes(skill)) {
            allCareerSkills.push(skill);
          }
        });
      });
      set(ffgData, 'career_skills', allCareerSkills);

      // Update is_career flag on skills
      let skills = ffgData.skills || [];
      skills.forEach(skill => {
        set(skill, 'is_career', allCareerSkills.includes(skill.name));
      });

      this.onUpdate();
    }
  }
});