module AresMUSH
  module Ffg
    
    def self.is_valid_career?(career)
      return false if !career
      careers = Global.read_config("ffg", "careers").map { |c| c['name'].downcase }
      careers.include?(career.downcase)
    end
    
    def self.is_valid_archetype?(type)
      return false if !type
      types = Global.read_config("ffg", "archetypes").map { |c| c['name'].downcase }
      types.include?(type.downcase)
    end
    
    def self.is_valid_specialization?(spec)
      return false if !spec
      specs = Global.read_config("ffg", "specializations").map { |c| c['name'].downcase }
      specs.include?(spec.downcase)
    end
    
    def self.use_force?
      Global.read_config('ffg', 'use_force')
    end
    
    def self.is_valid_characteristic_name?(name)
      return false if !name
      names = Global.read_config('ffg', 'characteristics').map { |a| a['name'].downcase }
      names.include?(name.downcase)
    end
    
    def self.is_valid_skill_name?(name)
      return false if !name
      names = Global.read_config('ffg', 'skills').map { |a| a['name'].downcase }
      names.include?(name.downcase)
    end
    
    def self.can_manage_abilities?(actor)
      return false if !actor
      actor.has_permission?("manage_apps")
    end
    
    def self.check_max_starting_rating(rating, config_setting)
      max_rating = Global.read_config("ffg", config_setting)
      return nil if rating <= max_rating
      return t('ffg.starting_rating_limit', :rating => max_rating)
    end
    
    def self.skill_rating(char, ability_name)
      skill = Ffg.find_skill(char, ability_name)
      skill ? skill.rating : 0
    end
    
    def self.characteristic_rating(char, ability_name)
      charac = Ffg.find_characteristic(char, ability_name)
      charac ? charac.rating : 0
    end
    
    def self.find_characteristic(char, ability_name)
      name_downcase = ability_name.downcase
      char.ffg_characteristics.select { |a| a.name.downcase == name_downcase }.first
    end
    
    def self.find_skill(char, ability_name)
      name_downcase = ability_name.downcase
      char.ffg_skills.select { |a| a.name.downcase == name_downcase }.first
    end
    
    def self.find_talent(char, ability_name)
      name_downcase = ability_name.downcase
      char.ffg_talents.select { |a| a.name.downcase == name_downcase }.first
    end    
        
    def self.find_talent_config(ability_name)
      return nil if !ability_name
      assets = Global.read_config('ffg', 'talents')
      assets.select { |a| a['name'].downcase == ability_name.downcase }.first
    end

    def self.find_skill_config(name)
      return nil if !name
      types = Global.read_config('ffg', 'skills')
      types.select { |a| a['name'].downcase == name.downcase }.first
    end    
    
    def self.find_archetype_config(name)
      return nil if !name
      types = Global.read_config('ffg', 'archetypes')
      types.select { |a| a['name'].downcase == name.downcase }.first
    end

    def self.find_career_config(name)
      return nil if !name
      careers = Global.read_config('ffg', 'careers')
      careers.select { |a| a['name'].downcase == name.downcase }.first
    end
    
    def self.find_specialization_config(name)
      return nil if !name
      specs = Global.read_config('ffg', 'specializations')
      specs.select { |a| a['name'].downcase == name.downcase }.first
    end
    
    def self.specializations_for_career(career)
      specs = Global.read_config('ffg', 'specializations')
      specs.select { |s| !s['career'].blank? && s['career'].downcase == career.downcase }
    end
    
    def self.universal_specializations
      specs = Global.read_config('ffg', 'specializations')
      specs.select { |s| s['career'].blank? }
    end
    
    def self.set_characteristic(char, ability_name, rating)
      charac = Ffg.find_characteristic(char, ability_name)
      
      if (charac && rating < 1)
        charac.delete
        return
      end
      
      if (charac)
        charac.update(rating: rating)
      else
        FfgCharacteristic.create(name: ability_name, rating: rating, character: char)
      end
      
      if (!char.is_approved?)
        Ffg.update_thresholds(char)
      end
    end
    
    def self.can_change_specs?(char)
      return false if !char
      return true if char.is_approved?
      return false if !char.ffg_archetype
      
      archetype_config = Ffg.find_archetype_config(char.ffg_archetype)
      
      char.ffg_talents.each do |t|
        if (!archetype_config['talents'].include?(t.name) || t.rating > 1)
          return false
        end
      end
      
      char.ffg_skills.each do |t|
        if (!archetype_config['skills'].include?(t.name) || t.rating > 1)
          return false
        end
      end
      return true
    end
    
    def self.set_skill(char, ability_name, rating)
      skill = Ffg.find_skill(char, ability_name)
      if (skill && rating < 1)
        skill.delete
        return
      end
      
      if (skill)
        skill.update(rating: rating)
      else
        FfgSkill.create(name: ability_name, rating: rating, character: char)
      end
    end
    
    
    def self.is_force_user?(char)
      return false if !Ffg.use_force?
      return false if !char
      return char.ffg_specializations && char.ffg_specializations.any? { |s| Ffg.is_force_spec?(s) }
    end 
    
    def self.is_force_spec?(spec)
      config = Ffg.find_specialization_config(spec)
      config['force_user']
    end
    
    def self.update_thresholds(char)
      return if char.is_approved?
      config = Ffg.find_archetype_config(char.ffg_archetype)
      brawn = Ffg.find_characteristic(char, Global.read_config('ffg', 'wound_characteristic'))
      will = Ffg.find_characteristic(char, Global.read_config('ffg', 'strain_characteristic'))
      wound = config['wound'] + (brawn ? brawn.rating : 0)
      strain = config['strain'] + (will ? will.rating : 0)
      
      char.update(ffg_wound_threshold: wound)
      char.update(ffg_strain_threshold: strain)
      
    end
    
    def self.is_career_skill?(char, skill)
      char.ffg_specializations.each do |spec|
        config = Ffg.find_specialization_config(spec)
        career_skills = config['career_skills'] || []
        return true if career_skills.include?(skill)
      end
      config = Ffg.find_career_config(char.ffg_career)
      return false if !config
      career_skills = config['career_skills'] || []
      return career_skills.include?(skill)
    end
    
    def self.is_career_specialization?(char, spec)
      config = Ffg.find_specialization_config(spec)
      career = config['career']
      career.blank? || (career == char.ffg_career)
    end

    # Data for web sheets/chargen.
    # - In normal view: use SheetTemplate (live char data).
    # - In chargen: build a full list from config so the
    #   web UI has something to show even for new chars.
    def self.build_web_char_data(char, viewer, chargen)
      if !chargen
        # Sheet view – reuse your existing sheet template.
        sheet = SheetTemplate.new(char)
        return sheet.to_h
      end

      # === CHARGEN VIEW ===

      # Config lists (from the ffg_* config files)
      config_chars  = Global.read_config("ffg", "characteristics") || []
      config_skills = Global.read_config("ffg", "skills") || []
      config_talents = Global.read_config("ffg", "talents") || []

      # Build characteristics list: always one row per config entry.
      characteristics = config_chars.map do |c|
        # If the char already has a record, use its rating; otherwise 0.
        rec = char.ffg_characteristics.find(name: c['name']).first rescue nil
        {
          name:  c['name'],
          desc:  c['description'],
          rating: rec ? rec.rating : 0
        }
      end

      # Build skills list the same way.
      skills = config_skills.map do |s|
        rec = char.ffg_skills.find(name: s['name']).first rescue nil
        {
          name:           s['name'],
          desc:           s['description'],
          characteristic: s['characteristic'],
          rating:         rec ? rec.rating : 0
        }
      end

      # For chargen we normally only care about already-picked talents.
      talents = char.ffg_talents.map do |t|
        {
          name:           t.name,
          rank:           t.ranked ? t.rating : nil,
          tier:           t.tier,
          specialization: t.specialization
        }
      end

      wounds = {
        current: char.ffg_wounds || 0,
        max:     char.ffg_wound_threshold || 0
      }

      strain = {
        current: char.ffg_strain || 0,
        max:     char.ffg_strain_threshold || 0
      }

      {
        summary:         nil, # you can wire this later if you want
        characteristics: characteristics,
        skills:          skills,
        talents:         talents,
        wounds:          wounds,
        strain:          strain
      }
    end

    # Build web chargen config info (limits, XP rules, etc.)
    # Values come from game/config/ffg_general.yml (ffg: ...).
    def self.build_web_chargen_info
      {
        max_cg_characteristic_rating: Global.read_config("ffg", "max_cg_characteristic_rating"),
        max_cg_skill_rating:         Global.read_config("ffg", "max_cg_skill_rating"),
        bonus_xp:                    Global.read_config("ffg", "bonus_xp"),
        career_skill_xp:             Global.read_config("ffg", "career_skill_xp"),
        use_force:                   Global.read_config("ffg", "use_force"),
        min_career_skills:           Global.read_config("ffg", "min_career_skills"),
        wound_characteristic:        Global.read_config("ffg", "wound_characteristic"),
        strain_characteristic:       Global.read_config("ffg", "strain_characteristic")
      }
    end
  end
end