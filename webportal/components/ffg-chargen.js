import Component from '@ember/component';
import { inject as service } from '@ember/service';
import { computed } from '@ember/object';
import { set } from '@ember/object';

export default Component.extend({
  tagName: '',
  flashMessages: service(),
  gameApi: service(),
  selectedSpecName: null,
  needsReset: computed('char.custom.ffg.archetype', function() {
    return !this.get('char.custom.ffg.archetype');
  }),

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

  // Check if character is a Force user
  isForceUser: computed('ffgData.specializations.@each.force_user', function() {
    let specs = this.get('ffgData.specializations') || [];
    return specs.some(spec => spec.force_user);
  }),

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

  // Calculate characteristic XP cost
  _calculateCharacteristicCost(oldRating, newRating) {
    let cost = 0;
    for (let rating = oldRating + 1; rating <= newRating; rating++) {
      cost += rating * 10;
    }
    return cost;
  },

  // Calculate skill XP cost
  _calculateSkillCost(skillName, oldRating, newRating, isCareer) {
    let cost = 0;
    for (let rating = oldRating + 1; rating <= newRating; rating++) {
      cost += (rating * 5) + (isCareer ? 0 : 5);
    }
    return cost;
  },

  // Calculate specialization XP cost
  _calculateSpecializationCost(specIndex, isCareer) {
    if (specIndex === 0) {
      return 0; // First spec is free
    }
    return ((specIndex + 1) * 10) + (isCareer ? 0 : 10);
  },

  // Calculate talent XP cost
  _calculateTalentCost(talentName, oldRating, newRating) {
    let cgInfo = this.get('cgInfo');
    let talentConfig = (cgInfo.talents || []).find(t => t.name === talentName);
    if (!talentConfig) {
      return 0;
    }

    let tier = talentConfig.tier || 1;
    let cost = 0;
    for (let rating = oldRating + 1; rating <= newRating; rating++) {
      cost += (rating + tier - 1) * 5;
    }
    return cost;
  },

  // Calculate force power XP cost (base cost plus each purchased upgrade)
  _calculateForcePowerCost(powerName, upgrades) {
    let cgInfo = this.get('cgInfo');
    let powerConfig = (cgInfo.force_powers || []).find(p => p.name === powerName);
    if (!powerConfig) {
      return 0;
    }

    let cost = powerConfig.base_xp_cost || 10;
    let upgradesConfig = powerConfig.upgrades || [];

    (upgrades || []).forEach(upgradeName => {
      let upgradeConfig = upgradesConfig.find(u => u.name === upgradeName);
      cost += upgradeConfig ? (upgradeConfig.xp_cost || 5) : 0;
    });

    return cost;
  },

  // Check if specialization is career specialization
  _isCareerSpecialization(specName) {
    let careerName = this.get('ffgData.career.name');
    let cgInfo = this.get('cgInfo');
    let specConfig = (cgInfo.specializations || []).find(s => s.name === specName);
    
    if (!specConfig) {
      return false;
    }
    
    return !specConfig.career || specConfig.career === careerName;
  },

  // Calculate total spent XP based on current abilities FROM BASELINE
  spentXP: computed(
    'ffgData.characteristics.@each.rating',
    'ffgData.skills.@each.rating',
    'ffgData.specializations.@each.name',
    'ffgData.talents.@each.{name,rank}',
    'ffgData.force_powers.@each.{name,upgrades}',
    'ffgData.archetype.characteristics',
    'ffgData.archetype.skills',
    'ffgData.archetype.talents',
    'ffgData.career_skills',
    function() {
      let ffgData = this.get('ffgData');
      let totalSpent = 0;

      // Calculate characteristic costs FROM ARCHETYPE BASELINE
      let characteristics = ffgData.characteristics || [];
      let archetypeCharacs = (ffgData.archetype && ffgData.archetype.characteristics) || {};
      
      characteristics.forEach(c => {
        let currentRating = c.rating || 0;
        let startingRating = archetypeCharacs[c.name] || 0;
        
        if (currentRating > startingRating) {
          totalSpent += this._calculateCharacteristicCost(startingRating, currentRating);
        }
      });

      // Calculate skill costs FROM BASELINE
      let skills = ffgData.skills || [];
      let careerSkills = ffgData.career_skills || [];
      let archetypeSkills = (ffgData.archetype && ffgData.archetype.skills) || [];
      
      skills.forEach(s => {
        let currentRating = s.rating || 0;
        let startingRating = archetypeSkills.includes(s.name) ? 1 : 0;
        
        if (currentRating > startingRating) {
          let isCareer = careerSkills.includes(s.name);
          totalSpent += this._calculateSkillCost(s.name, startingRating, currentRating, isCareer);
        }
      });

      // Calculate specialization costs (first is free)
      let specializations = ffgData.specializations || [];
      specializations.forEach((spec, index) => {
        if (index > 0) {
          let isCareer = this._isCareerSpecialization(spec.name);
          totalSpent += this._calculateSpecializationCost(index, isCareer);
        }
      });

      // Calculate talent costs (accounting for archetype freebies)
      let talents = ffgData.talents || [];
      let archetypeTalents = (ffgData.archetype && ffgData.archetype.talents) || [];
      
      talents.forEach(t => {
        let rank = t.rank || t.rating || 1;
        
        if (archetypeTalents.includes(t.name)) {
          // Archetype gave rank 1 free, only charge for additional
          if (rank > 1) {
            totalSpent += this._calculateTalentCost(t.name, 1, rank);
          }
        } else {
          // Charge for all ranks
          totalSpent += this._calculateTalentCost(t.name, 0, rank);
        }
      });

      // Calculate force power costs
      let forcePowers = ffgData.force_powers || [];
      forcePowers.forEach(p => {
        totalSpent += this._calculateForcePowerCost(p.name, p.upgrades);
      });

      return totalSpent;
    }
  ),

  // Calculate remaining XP
  remainingXP: computed('ffgData.starting_xp', 'spentXP', function() {
    let starting = this.get('ffgData.starting_xp') || 0;
    let spent = this.get('spentXP') || 0;
    return starting - spent;
  }),

  actions: {
    abilityChanged() {
      this.onUpdate();
    },

    resetAbilities() {
      let archetype = this.get('selectedArchetype');
      let career = this.get('selectedCareer');
      
      if (!archetype || !career) {
        this.get('flashMessages').danger('Please select both an archetype and career.');
        return;
      }
      
      let api = this.get('gameApi');
      
      api.requestOne('resetAbilities', { 
        archetype: archetype, 
        career: career 
      }).then((response) => {
        if (response.error) {
          this.get('flashMessages').danger(response.error);
        } else {
          // Update the character data with the reset baseline
          set(this.get('char'), 'custom', response.char);
          this.get('flashMessages').success('Character reset! You can now customize your abilities.');
        }
      });
    },

    selectArchetype(event) {
      this.set('selectedArchetype', event.target.value);
    },

    selectCareer(event) {
      this.set('selectedCareer', event.target.value);
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