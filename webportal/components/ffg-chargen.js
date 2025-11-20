import Component from '@ember/component';
import { set } from '@ember/object';
import { computed } from '@ember/object';

export default Component.extend({
  tagName: '',
  selectedSpecName: null,

  didInsertElement() {
    this._super(...arguments);
    console.log('ffg-chargen: didInsertElement');
  },

  // Computed property for available specs
  availableSpecs: computed('char.custom.cg_ffg.specializations', 'char.custom.ffg.career.name', 'char.custom.ffg.specializations.@each.name', function() {
    let allSpecs = this.get('char.custom.cg_ffg.specializations') || [];
    let careerName = this.get('char.custom.ffg.career.name');
    let currentSpecs = (this.get('char.custom.ffg.specializations') || []).map(s => s.name);
    
    return allSpecs.filter(spec => {
      if (currentSpecs.includes(spec.name)) {
        return false;
      }
      return !spec.career || spec.career === careerName;
    });
  }),

  // Calculate XP cost for a characteristic increase
  calculateCharacteristicCost(oldRating, newRating) {
    let cost = 0;
    for (let rating = oldRating + 1; rating <= newRating; rating++) {
      cost += rating * 10;
    }
    return cost;
  },

  // Calculate XP cost for a skill increase
  calculateSkillCost(skillName, oldRating, newRating, isCareer) {
    let cost = 0;
    for (let rating = oldRating + 1; rating <= newRating; rating++) {
      cost += (rating * 5) + (isCareer ? 0 : 5);
    }
    return cost;
  },

  // Calculate XP cost for specializations
  calculateSpecializationsCost(specs) {
    if (!specs || specs.length === 0) return 0;
    
    // First spec is free
    let cost = 0;
    let ffgData = this.get('char.custom.ffg');
    let career = ffgData.career ? ffgData.career.name : null;
    
    for (let i = 1; i < specs.length; i++) {
      let spec = specs[i];
      let isCareerSpec = spec.career === career || !spec.career;
      cost += ((i + 1) * 10) + (isCareerSpec ? 0 : 10);
    }
    
    return cost;
  },

  // Computed property for spent XP
  spentXP: computed(
    'char.custom.ffg.archetype',
    'char.custom.ffg.characteristics.@each.rating',
    'char.custom.ffg.skills.@each.rating',
    'char.custom.ffg.specializations.[]',
    'char.custom.ffg.talents.[]',
    function() {
      let ffgData = this.get('char.custom.ffg') || {};
      let archetype = ffgData.archetype;
      
      if (!archetype) return 0;
      
      let totalSpent = 0;
      
      // Calculate characteristic costs
      let characteristics = ffgData.characteristics || [];
      characteristics.forEach(c => {
        let startingRating = archetype.characteristics[c.name] || 0;
        let currentRating = c.rating || 0;
        if (currentRating > startingRating) {
          totalSpent += this.calculateCharacteristicCost(startingRating, currentRating);
        }
      });
      
      // Calculate skill costs
      let skills = ffgData.skills || [];
      skills.forEach(s => {
        let currentRating = s.rating || 0;
        if (currentRating > 0) {
          totalSpent += this.calculateSkillCost(s.name, 0, currentRating, s.is_career);
        }
      });
      
      // Calculate specialization costs
      let specs = ffgData.specializations || [];
      totalSpent += this.calculateSpecializationsCost(specs);
      
      // Calculate talent costs
      let talents = ffgData.talents || [];
      talents.forEach(t => {
        let tier = t.tier || 1;
        let rank = t.rank || 1;
        
        // Base cost is tier * 5
        // For ranked talents, each rank costs (tier + rank - 1) * 5
        if (rank > 1) {
          for (let r = 1; r <= rank; r++) {
            totalSpent += (tier + r - 1) * 5;
          }
        } else {
          totalSpent += tier * 5;
        }
      });
      
      return totalSpent;
    }
  ),

  // Computed property for current XP
  currentXP: computed('char.custom.ffg.starting_xp', 'spentXP', function() {
    let starting = this.get('char.custom.ffg.starting_xp') || 0;
    let spent = this.get('spentXP') || 0;
    return starting - spent;
  }),

  actions: {
    abilityChanged() {
      if (this.updated) {
        this.updated();
      }
    },

    selectArchetype(event) {
      let archetypeName = event.target.value;
      if (!archetypeName) { return; }

      let cgInfo = this.get('char.custom.cg_ffg');
      let archetypes = cgInfo.archetypes || [];
      let archetype = archetypes.find(a => a.name === archetypeName);
      
      if (!archetype) { return; }

      console.log('Setting archetype:', archetypeName);

      set(this.get('char.custom.ffg'), 'archetype', {
        name: archetype.name,
        characteristics: archetype.characteristics,
        wound: archetype.wound,
        strain: archetype.strain,
        xp: archetype.xp
      });

      let characteristics = this.get('char.custom.ffg.characteristics') || [];
      characteristics.forEach(c => {
        let archetypeValue = archetype.characteristics[c.name] || 0;
        set(c, 'rating', archetypeValue);
      });

      let bonus_xp = cgInfo.bonus_xp || 0;
      let career_xp = cgInfo.career_skill_xp || 0;
      set(this.get('char.custom.ffg'), 'starting_xp', archetype.xp + bonus_xp + career_xp);

      if (this.updated) {
        this.updated();
      }
    },

    selectCareer(event) {
      let careerName = event.target.value;
      if (!careerName) { return; }

      let cgInfo = this.get('char.custom.cg_ffg');
      let careers = cgInfo.careers || [];
      let career = careers.find(c => c.name === careerName);
      
      if (!career) { return; }

      console.log('Setting career:', careerName);

      set(this.get('char.custom.ffg'), 'career', {
        name: career.name,
        career_skills: career.career_skills || []
      });

      set(this.get('char.custom.ffg'), 'career_skills', career.career_skills || []);

      // Update is_career flag on all skills
      let skills = this.get('char.custom.ffg.skills') || [];
      let allCareerSkills = career.career_skills || [];
      skills.forEach(skill => {
        set(skill, 'is_career', allCareerSkills.includes(skill.name));
      });

      if (this.updated) {
        this.updated();
      }
    },

    updateSpecSelection(event) {
      this.set('selectedSpecName', event.target.value);
    },

    addSpecialization() {
      let specName = this.get('selectedSpecName');
      if (!specName) { return; }

      let cgInfo = this.get('char.custom.cg_ffg');
      let allSpecs = cgInfo.specializations || [];
      let specConfig = allSpecs.find(s => s.name === specName);
      
      if (!specConfig) { return; }

      let ffgData = this.get('char.custom.ffg');
      let specializations = ffgData.specializations || [];
      
      if (specializations.find(s => s.name === specName)) {
        return;
      }

      // Create a NEW array instead of using pushObject
      let newSpecs = [...specializations, {
        name: specConfig.name,
        career: specConfig.career,
        career_skills: specConfig.career_skills || [],
        force_user: specConfig.force_user
      }];
      
      // Set the new array
      set(ffgData, 'specializations', newSpecs);

      // Update career_skills
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
      
      if (this.updated) {
        this.updated();
      }
    },

    removeSpecialization(specName) {
      if (!confirm(`Remove specialization: ${specName}?`)) {
        return;
      }

      let ffgData = this.get('char.custom.ffg');
      let specializations = ffgData.specializations || [];
      
      // Create a NEW array with the spec removed
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

      if (this.updated) {
        this.updated();
      }
    }
  }
});