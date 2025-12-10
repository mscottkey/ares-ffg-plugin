import Component from '@ember/component';
import { inject as service } from '@ember/service';
import { set } from '@ember/object';

export default Component.extend({
  tagName: '',
  flashMessages: service(),
  gameApi: service(),
  selectedArchetype: null,
  selectedCareer: null,
  
  didInsertElement: function() {
    this._super(...arguments);
    let self = this;
    this.set('updateCallback', function() { return self.onUpdate(); } );
  },
  
  onUpdate: function() {
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
        wounds: ffg.wounds,
        strain: ffg.strain
      }
    };
  },
  
  validateChar: function() {
    // Your existing validation logic
  },
  
  actions: {
    abilityChanged() {
      this.validateChar();
    },
    
    selectArchetype(event) {
      this.set('selectedArchetype', event.target.value);
    },
    
    selectCareer(event) {
      this.set('selectedCareer', event.target.value);
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
          // Update the character with the reset baseline
          set(this.get('char'), 'custom', response.char);
          this.get('flashMessages').success('Character reset! You can now customize your abilities.');
          this.validateChar();
        }
      });
    }
  }
});