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

    # ------------------------------------------------------------
    # Web sheet / chargen data
    # ------------------------------------------------------------

    # Data for web sheets/chargen.
    # - In normal view: use SheetTemplate (live char data).
    # - In chargen: build a full list from config so the
    #   web UI has something to show even for new chars.
    def self.build_web_char_data(char, viewer, chargen)
      if !chargen
        sheet = SheetTemplate.new(char)
        return sheet.to_h
      end

      # === CHARGEN VIEW ===
      config_chars   = Global.read_config("ffg", "characteristics") || []
      config_skills  = Global.read_config("ffg", "skills") || []

      # Build list of all career skills
      all_career_skills = []
      if char.ffg_career
        career_config = Ffg.find_career_config(char.ffg_career)
        all_career_skills = career_config ? (career_config['career_skills'] || []) : []
      end
      
      # Add specialization skills
      (char.ffg_specializations || []).each do |spec_name|
        spec_config = Ffg.find_specialization_config(spec_name)
        if spec_config
          all_career_skills += (spec_config['career_skills'] || [])
        end
      end
      all_career_skills = all_career_skills.uniq

      # IMPORTANT: Convert to plain arrays/hashes, not AR objects
      characteristics = config_chars.map do |c|
        rec = char.ffg_characteristics.select { |a| a.name == c['name'] }.first
        {
          'name'   => c['name'],
          'desc'   => c['description'],
          'rating' => rec ? rec.rating : 0
        }
      end

      # Build skills list with career flag
      skills = config_skills.map do |s|
        rec = char.ffg_skills.select { |a| a.name == s['name'] }.first
        {
          'name'           => s['name'],
          'desc'           => s['description'],
          'characteristic' => s['characteristic'],
          'rating'         => rec ? rec.rating : 0,
          'is_career'      => all_career_skills.include?(s['name'])
        }
      end

      talents = char.ffg_talents.map do |t|
        {
          'name'           => t.name,
          'rank'           => t.ranked ? t.rating : nil,
          'tier'           => t.tier,
          'specialization' => t.specialization
        }
      end

      # Get archetype info
      archetype_data = nil
      if char.ffg_archetype
        arch_config = Ffg.find_archetype_config(char.ffg_archetype)
        if arch_config
          archetype_data = {
            'name' => char.ffg_archetype,
            'characteristics' => arch_config['characteristics'],
            'wound' => arch_config['wound'],
            'strain' => arch_config['strain'],
            'xp' => arch_config['xp']
          }
        end
      end

      # Get career info
      career_data = nil
      if char.ffg_career
        career_config = Ffg.find_career_config(char.ffg_career)
        if career_config
          career_data = {
            'name' => char.ffg_career,
            'career_skills' => career_config['career_skills'] || []
          }
        end
      end

      # Get specializations
      specializations = (char.ffg_specializations || []).map do |spec_name|
        spec_config = Ffg.find_specialization_config(spec_name)
        if spec_config
          {
            'name' => spec_name,
            'career' => spec_config['career'],
            'career_skills' => spec_config['career_skills'] || [],
            'force_user' => spec_config['force_user']
          }
        else
          { 'name' => spec_name }
        end
      end.compact

      starting_xp = archetype_data ? (archetype_data['xp'] || 0) : 0
      bonus_xp = Global.read_config('ffg', 'bonus_xp') || 0
      career_xp = Global.read_config('ffg', 'career_skill_xp') || 0

      {
        'archetype'       => archetype_data,
        'career'          => career_data,
        'specializations' => specializations,
        'characteristics' => characteristics,
        'skills'          => skills,
        'talents'         => talents,
        'wounds'          => {
          'current' => char.ffg_wounds || 0,
          'max'     => char.ffg_wound_threshold || 0
        },
        'strain'          => {
          'current' => char.ffg_strain || 0,
          'max'     => char.ffg_strain_threshold || 0
        },
        'career_skills'   => all_career_skills,
        'starting_xp'     => starting_xp + bonus_xp + career_xp,
        'current_xp'      => char.ffg_xp || 0
      }
    end

    # Build web chargen config info (limits, XP rules, etc.)
    # Values come from game/config/ffg_general.yml (ffg: ...).
    def self.build_web_chargen_info
      archetypes_config = Global.read_config("ffg", "archetypes") || []
      careers_config = Global.read_config("ffg", "careers") || []
      specs_config = Global.read_config("ffg", "specializations") || []
      
      {
        'max_cg_characteristic_rating' => Global.read_config("ffg", "max_cg_characteristic_rating"),
        'max_cg_skill_rating'          => Global.read_config("ffg", "max_cg_skill_rating"),
        'talents'                      => Global.read_config('ffg', 'talents') || [],
        'bonus_xp'                     => Global.read_config("ffg", "bonus_xp"),
        'career_skill_xp'              => Global.read_config("ffg", "career_skill_xp"),
        'use_force'                    => Global.read_config("ffg", "use_force"),
        'min_career_skills'            => Global.read_config("ffg", "min_career_skills"),
        'wound_characteristic'         => Global.read_config("ffg", "wound_characteristic"),
        'strain_characteristic'        => Global.read_config("ffg", "strain_characteristic"),
        'archetypes'                   => archetypes_config.map { |a| {
          'name' => a['name'],
          'characteristics' => a['characteristics'],
          'wound' => a['wound'],
          'strain' => a['strain'],
          'xp' => a['xp'],
          'skills' => a['skills'] || [],
          'talents' => a['talents'] || []
        }},
        'careers'                      => careers_config.map { |c| {
          'name' => c['name'],
          'career_skills' => c['career_skills'] || []
        }},
        'specializations'              => specs_config.map { |s| {
          'name' => s['name'],
          'career' => s['career'],
          'career_skills' => s['career_skills'] || [],
          'force_user' => s['force_user']
        }}
      }
    end

    # ------------------------------------------------------------
    # Web chargen save hook – server-side validation
    # ------------------------------------------------------------

    # Save web chargen abilities (characteristics + skills + talents).
    # Returns an array of error strings; empty if everything is OK.
    def self.save_abilities(char, chargen_data)
      errors = []

      # Debug logging
      Global.logger.debug "FFG save_abilities called for #{char.name}"
      Global.logger.debug "FFG chargen_data keys: #{chargen_data.keys.inspect}"
      
      custom = chargen_data['custom']
      if !custom
        Global.logger.warn "FFG: No custom data in chargen_data"
        return errors
      end
      
      Global.logger.debug "FFG custom keys: #{custom.keys.inspect}"
      
      ffg = custom['ffg']
      if !ffg
        Global.logger.warn "FFG: No ffg data in custom"
        return errors
      end
      
      Global.logger.debug "FFG ffg keys: #{ffg.keys.inspect}"

      # Handle archetype
      archetype_data = ffg['archetype']
      if archetype_data && archetype_data['name']
        archetype_name = archetype_data['name']
        Global.logger.info "FFG: Setting archetype to #{archetype_name}"
        
        if Ffg.is_valid_archetype?(archetype_name)
          if char.ffg_archetype != archetype_name
            Global.logger.info "FFG: Archetype changed, resetting character"
            char.update(ffg_archetype: archetype_name)
            char.delete_ffg_abilities
            
            config = Ffg.find_archetype_config(archetype_name)
            
            # Set starting characteristics from archetype
            (config['characteristics'] || {}).each do |name, rating|
              Ffg.set_characteristic(char, name, rating)
            end
            
            # Set starting XP
            bonus_xp = Global.read_config('ffg', 'bonus_xp') || 0
            career_xp = Global.read_config('ffg', 'career_skill_xp') || 0
            char.update(ffg_xp: config['xp'] + bonus_xp + career_xp)
            
            # Set bonuses
            Ffg.set_archetype_bonuses(char, archetype_name)
            Ffg.update_thresholds(char)
          end
        else
          Global.logger.warn "FFG: Invalid archetype: #{archetype_name}"
          errors << t('ffg.invalid_archetype')
        end
      end

      # Handle career
      career_data = ffg['career']
      if career_data && career_data['name']
        career_name = career_data['name']
        Global.logger.info "FFG: Setting career to #{career_name}"
        
        if Ffg.is_valid_career?(career_name)
          if char.ffg_career != career_name
            char.update(ffg_career: career_name)
            Ffg.set_career_bonuses(char, career_name)
          end
        else
          Global.logger.warn "FFG: Invalid career: #{career_name}"
          errors << t('ffg.invalid_career')
        end
      end

      # Handle specializations
      specializations = ffg['specializations'] || []
      spec_names = specializations.map { |s| s['name'] }.compact
      spec_names.each do |spec_name|
        if !Ffg.is_valid_specialization?(spec_name)
          Global.logger.warn "FFG: Invalid specialization: #{spec_name}"
          errors << t('ffg.invalid_specialization')
        end
      end
      valid_specs = spec_names.select { |s| Ffg.is_valid_specialization?(s) }
      char.update(ffg_specializations: valid_specs)
      Global.logger.info "FFG: Set specializations to #{valid_specs.inspect}"

      # Handle characteristics
      characteristics = ffg['characteristics'] || []
      max_char = Global.read_config("ffg", "max_cg_characteristic_rating") || 5

      Global.logger.debug "FFG: Processing #{characteristics.length} characteristics"
      characteristics.each do |row|
        name = row['name']
        rating = (row['rating'] || 0).to_i

        if rating > max_char
          errors << t('ffg.char_rating_too_high', :name => name, :max => max_char)
          next
        end

        Ffg.set_characteristic(char, name, rating)
      end

      # Handle skills
      skills = ffg['skills'] || []
      max_skill = Global.read_config("ffg", "max_cg_skill_rating") || 2

      Global.logger.debug "FFG: Processing #{skills.length} skills"
      skills.each do |row|
        name = row['name']
        rating = (row['rating'] || 0).to_i

        if rating > max_skill
          errors << t('ffg.skill_rating_too_high', :name => name, :max => max_skill)
          next
        end

        Ffg.set_skill(char, name, rating)
      end

      # Handle talents
      talents = ffg['talents'] || []
      
      Global.logger.debug "FFG: Processing #{talents.length} talents"
      begin
        # Clear existing talents
        char.ffg_talents.to_a.each { |t| t.delete }

        talents.each do |row|
          name = row['name']
          next if name.blank?

          config = Ffg.find_talent_config(name)
          if !config
            Global.logger.warn "FFG: Unknown talent: #{name}"
            errors << "Unknown talent: #{name}"
            next
          end

          tier = (row['tier'] || config['tier'] || 1).to_i
          rank = (row['rank'] || 1).to_i
          spec = row['specialization']
          ranked = !!config['ranked']

          FfgTalent.create(
            character: char,
            name: name,
            tier: tier,
            ranked: ranked,
            rating: ranked ? rank : 1,
            specialization: spec
          )
        end
      rescue => e
        Global.logger.error "FFG: Error saving talents for #{char.name}: #{e}"
        Global.logger.error e.backtrace.join("\n")
        errors << "There was a problem saving your talents. Please try again or contact staff."
      end

      Global.logger.info "FFG: save_abilities completed for #{char.name} with #{errors.length} errors"
      errors
    end
  end
end