module AresMUSH
  module Ffg  
    
    def self.app_review(char)
      review = []
      
      # Check archetype and career are set
      if (!char.ffg_archetype || !char.ffg_career)
        review << Chargen.format_review_status(t('ffg.must_set_archetype'), t('chargen.not_set'))
        return review.join("%r")
      end
      
      # Check characteristics
      review << check_characteristics_review(char)
      
      # Check skills
      review << skill_review(char)
      
      # Check specializations (if used)
      if Global.read_config('ffg', 'specializations')&.any?
        review << check_specializations_review(char)
      end
      
      # Check talents
      review << check_talents_review(char)
      
      # Check XP budget
      review << check_xp_budget(char)
      
      review.join("%r")
    end
    
    def self.check_characteristics_review(char)
      max_rating = Global.read_config('ffg', 'max_cg_characteristic_rating') || 5
      archetype_config = Ffg.find_archetype_config(char.ffg_archetype)
      archetype_characs = (archetype_config && archetype_config['characteristics']) || {}
      
      violations = []
      char.ffg_characteristics.each do |c|
        if c.rating > max_rating
          violations << "#{c.name} (#{c.rating})"
        end
        
        min_rating = archetype_characs[c.name] || 0
        if c.rating < min_rating
          violations << "#{c.name} below minimum (#{c.rating} < #{min_rating})"
        end
      end
      
      if violations.any?
        message = "Invalid characteristics: #{violations.join(', ')}"
        return Chargen.format_review_status(message, t('chargen.not_set'))
      end
      
      Chargen.format_review_status(t('ffg.characteristics_title'), t('chargen.ok'))
    end
      
    def self.skill_review(char)
      max_rating = Global.read_config('ffg', 'max_cg_skill_rating') || 2
      min_career_skills = Global.read_config('ffg', 'min_career_skills') || 4
      
      # Check for over-rated skills
      violations = char.ffg_skills.select { |s| s.rating > max_rating }
      if violations.any?
        names = violations.map { |s| "#{s.name} (#{s.rating})" }.join(", ")
        message = "Skills above maximum (#{max_rating}): #{names}"
        return Chargen.format_review_status(message, t('chargen.not_set'))
      end
      
      # Check career skill minimum
      career_config = Ffg.find_career_config(char.ffg_career)
      career_skills = career_config ? (career_config['career_skills'] || []) : []
      
      # Add specialization skills
      (char.ffg_specializations || []).each do |spec|
        spec_config = Ffg.find_specialization_config(spec)
        if spec_config
          career_skills += (spec_config['career_skills'] || [])
        end
      end
      career_skills.uniq!
      
      taken = career_skills.count { |skill| Ffg.skill_rating(char, skill) > 0 }
      
      message = t('ffg.career_skills_taken', taken: taken, min: min_career_skills)
      status = taken >= min_career_skills ? t('chargen.ok') : t('chargen.not_enough')
      Chargen.format_review_status(message, status)
    end
    
    def self.check_specializations_review(char)
      return "" if !char.ffg_specializations || char.ffg_specializations.empty?
      
      # First spec must be career or universal
      first_spec = char.ffg_specializations.first
      if first_spec
        is_career = Ffg.is_career_specialization?(char, first_spec)
        if !is_career
          message = "First specialization must be career or universal"
          return Chargen.format_review_status(message, t('chargen.not_set'))
        end
      end
      
      # All specs must be valid
      invalid = char.ffg_specializations.reject { |s| Ffg.is_valid_specialization?(s) }
      if invalid.any?
        message = "Invalid specializations: #{invalid.join(', ')}"
        return Chargen.format_review_status(message, t('chargen.not_set'))
      end
      
      count = char.ffg_specializations.count
      message = "#{count} specialization#{count == 1 ? '' : 's'}"
      Chargen.format_review_status(message, t('chargen.ok'))
    end
    
    def self.check_talents_review(char)
      return "" if char.ffg_talents.empty?
      
      # Check pyramid balance
      counts = { 1 => 0, 2 => 0, 3 => 0, 4 => 0, 5 => 0 }
      char.ffg_talents.each do |t|
        tier = t.tier || 1
        counts[tier] += 1
      end
      
      balanced = (counts[1] >= counts[2] &&
                  counts[2] >= counts[3] &&
                  counts[3] >= counts[4] &&
                  counts[4] >= counts[5])
      
      if !balanced
        pyramid = [1, 2, 3, 4, 5].map { |t| "T#{t}:#{counts[t]}" }.join(" ")
        message = "Talent pyramid unbalanced (#{pyramid})"
        return Chargen.format_review_status(message, t('chargen.not_set'))
      end
      
      total = counts.values.sum
      message = "#{total} talent#{total == 1 ? '' : 's'} (pyramid balanced)"
      Chargen.format_review_status(message, t('chargen.ok'))
    end
    
    def self.check_xp_budget(char)
      spent = calculate_spent_xp(char)
      starting = calculate_starting_xp(char)
      remaining = char.ffg_xp || 0
      
      if spent + remaining != starting
        message = "XP mismatch: spent #{spent}, remaining #{remaining}, should total #{starting}"
        return Chargen.format_review_status(message, t('chargen.not_set'))
      end
      
      if remaining < 0
        message = "Over XP budget by #{-remaining} XP"
        return Chargen.format_review_status(message, t('chargen.not_set'))
      end
      
      message = "XP: #{spent}/#{starting} spent, #{remaining} remaining"
      Chargen.format_review_status(message, t('chargen.ok'))
    end
    
    def self.calculate_starting_xp(char)
      archetype_config = Ffg.find_archetype_config(char.ffg_archetype)
      return 0 if !archetype_config
      
      base_xp = archetype_config['xp'] || 0
      bonus_xp = Global.read_config('ffg', 'bonus_xp') || 0
      career_xp = Global.read_config('ffg', 'career_skill_xp') || 0
      
      base_xp + bonus_xp + career_xp
    end
    
    def self.calculate_spent_xp(char)
      spent = 0
      
      # Characteristics
      archetype_config = Ffg.find_archetype_config(char.ffg_archetype)
      archetype_characs = (archetype_config && archetype_config['characteristics']) || {}
      
      char.ffg_characteristics.each do |c|
        old_rating = archetype_characs[c.name] || 0
        if c.rating > old_rating
          spent += Ffg.characteristic_xp_cost(char, old_rating, c.rating)
        end
      end
      
      # Skills
      char.ffg_skills.each do |s|
        if s.rating > 0
          spent += Ffg.skill_xp_cost(char, s.name, 0, s.rating)
        end
      end
      
      # Specializations
      (char.ffg_specializations || []).each_with_index do |spec, index|
        spent += Ffg.specialization_xp_cost(char, spec, index)
      end
      
      # Talents (excluding archetype freebies)
      archetype_talents = (archetype_config && archetype_config['talents']) || []
      char.ffg_talents.each do |t|
        if archetype_talents.include?(t.name)
          # Archetype gives first rank free, charge for additional ranks
          if t.rating > 1
            spent += Ffg.talent_xp_cost(t.name, 1, t.rating)
          end
        else
          spent += Ffg.talent_xp_cost(t.name, 0, t.rating)
        end
      end
      
      spent
    end
    
  end
end