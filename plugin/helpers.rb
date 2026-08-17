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

    def self.find_force_power(char, power_name)
      name_downcase = power_name.downcase
      char.ffg_force_powers.select { |p| p.name.downcase == name_downcase }.first
    end

    def self.find_talent_config(ability_name)
      return nil if !ability_name
      assets = Global.read_config('ffg', 'talents')
      assets.select { |a| a['name'].downcase == ability_name.downcase }.first
    end

    def self.find_force_power_config(power_name)
      return nil if !power_name
      powers = Global.read_config('ffg', 'force_powers')
      powers.select { |p| p['name'].downcase == power_name.downcase }.first
    end

    def self.is_valid_force_power?(power_name)
      return false if !power_name
      power_config = find_force_power_config(power_name)
      !power_config.nil?
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

    # Builds a list of abilities (skills) for use in web rolling interfaces
    # Returns array of hashes with skill name and related characteristic
    def self.web_abilities(char)
      return [] if !char

      skills_config = Global.read_config("ffg", "skills") || []

      skills_config.map do |skill_config|
        skill_name = skill_config['name']
        characteristic = skill_config['characteristic']

        {
          name: skill_name,
          characteristic: characteristic
        }
      end.sort_by { |s| s[:name] }
    end

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
          'tier'           => t.tier
        }
      end

      force_powers = char.ffg_force_powers.map do |p|
        {
          'name'           => p.name,
          'upgrades'       => p.upgrades || []
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
        'force_powers'    => force_powers,
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
        'force_powers'                 => Global.read_config('ffg', 'force_powers') || [],
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
      
      custom = chargen_data[:custom] || chargen_data['custom']
      if !custom
        Global.logger.warn "FFG: No custom data in chargen_data"
        return errors
      end
      
      ffg = custom[:ffg] || custom['ffg']
      if !ffg
        Global.logger.warn "FFG: No ffg data in custom"
        return errors
      end

      # Handle archetype
      archetype_data = ffg[:archetype] || ffg['archetype']
      if archetype_data
        archetype_name = archetype_data[:name] || archetype_data['name']
        if archetype_name && Ffg.is_valid_archetype?(archetype_name)
          if char.ffg_archetype != archetype_name
            Global.logger.info "FFG: Archetype changed to #{archetype_name}, resetting character"
            char.update(ffg_archetype: archetype_name)
            char.delete_ffg_abilities
            
            config = Ffg.find_archetype_config(archetype_name)
            
            # Set starting characteristics from archetype
            (config['characteristics'] || {}).each do |name, rating|
              Ffg.set_characteristic(char, name, rating)
            end
            
            # Set starting skills from archetype
            (config['skills'] || []).each do |name|
              Ffg.set_skill(char, name, 1)
            end
            
            # Set starting talents from archetype
            (config['talents'] || []).each do |name|
              talent_config = Ffg.find_talent_config(name)
              if talent_config
                FfgTalent.create(
                  name: name,
                  character: char,
                  rating: talent_config['ranked'] ? 1 : 1,
                  tier: talent_config['tier'] || 1,
                  ranked: talent_config['ranked']
                )
              end
            end
            
            # Set starting XP
            bonus_xp = Global.read_config('ffg', 'bonus_xp') || 0
            career_xp = Global.read_config('ffg', 'career_skill_xp') || 0
            char.update(ffg_xp: config['xp'] + bonus_xp + career_xp)
            
            Ffg.set_archetype_bonuses(char, archetype_name)
            Ffg.update_thresholds(char)
          end
        elsif archetype_name
          Global.logger.warn "FFG: Invalid archetype: #{archetype_name}"
          errors << t('ffg.invalid_archetype')
        end
      end

      # Handle career
      career_data = ffg[:career] || ffg['career']
      if career_data
        career_name = career_data[:name] || career_data['name']
        if career_name && Ffg.is_valid_career?(career_name)
          if char.ffg_career != career_name
            Global.logger.info "FFG: Setting career to #{career_name}"
            char.update(ffg_career: career_name)
            Ffg.set_career_bonuses(char, career_name)
          end
        elsif career_name
          Global.logger.warn "FFG: Invalid career: #{career_name}"
          errors << t('ffg.invalid_career')
        end
      end

      # Handle specializations
      specializations = ffg[:specializations] || ffg['specializations'] || []
      spec_names = specializations.map { |s| s[:name] || s['name'] }.compact
      
      # Validate all specs
      spec_names.each do |spec_name|
        if !Ffg.is_valid_specialization?(spec_name)
          Global.logger.warn "FFG: Invalid specialization: #{spec_name}"
          errors << t('ffg.invalid_specialization')
        end
      end
      
      # Only save valid specs
      valid_specs = spec_names.select { |s| Ffg.is_valid_specialization?(s) }
      char.update(ffg_specializations: valid_specs)
      
      # Set specialization bonuses for each spec
      valid_specs.each do |spec|
        Ffg.set_specialization_bonuses(char, spec)
      end
      
      Global.logger.info "FFG: Set specializations to #{valid_specs.inspect}"

      # Handle characteristics
      characteristics = ffg[:characteristics] || ffg['characteristics'] || []
      max_char = Global.read_config("ffg", "max_cg_characteristic_rating") || 5
      archetype_config = Ffg.find_archetype_config(char.ffg_archetype)
      archetype_characs = (archetype_config && archetype_config['characteristics']) || {}

      Global.logger.debug "FFG: Processing #{characteristics.length} characteristics"
      characteristics.each do |row|
        name = row[:name] || row['name']
        rating = (row[:rating] || row['rating'] || 0).to_i
        
        next if name.nil?

        # Check against max rating
        if rating > max_char
          errors << t('ffg.char_rating_too_high', name: name, max: max_char)
          next
        end
        
        # Check against archetype minimum
        min_rating = archetype_characs[name] || 0
        if rating < min_rating
          errors << t('ffg.cant_lower_below_archetype_min')
          next
        end

        Ffg.set_characteristic(char, name, rating)
      end

      # Handle skills
      skills = ffg[:skills] || ffg['skills'] || []
      max_skill = Global.read_config("ffg", "max_cg_skill_rating") || 2

      Global.logger.debug "FFG: Processing #{skills.length} skills"
      skills.each do |row|
        name = row[:name] || row['name']
        rating = (row[:rating] || row['rating'] || 0).to_i
        
        next if name.nil?

        if rating > max_skill
          errors << t('ffg.skill_rating_too_high', name: name, max: max_skill)
          next
        end

        Ffg.set_skill(char, name, rating)
      end

      # Handle talents
      talents = ffg[:talents] || ffg['talents'] || []
      
      Global.logger.debug "FFG: Processing #{talents.length} talents"
      begin
        # Clear existing talents that aren't from archetype
        archetype_talents = (archetype_config && archetype_config['talents']) || []
        char.ffg_talents.to_a.each do |t|
          # Keep archetype talents at rating 1, remove others
          if archetype_talents.include?(t.name)
            if t.rating > 1
              t.update(rating: 1)
            end
          else
            t.delete
          end
        end

        # Add/update talents from chargen
        talents.each do |row|
          name = row[:name] || row['name']
          next if name.blank?

          config = Ffg.find_talent_config(name)
          if !config
            Global.logger.warn "FFG: Unknown talent: #{name}"
            errors << "Unknown talent: #{name}"
            next
          end

          tier = (row[:tier] || row['tier'] || config['tier'] || 1).to_i
          rank = (row[:rank] || row['rank'] || 1).to_i
          ranked = !!config['ranked']
          
          # Check if this is an archetype talent
          is_archetype_talent = archetype_talents.include?(name)

          # Find existing talent
          existing = char.ffg_talents.select { |t| t.name == name }.first
          
          if existing
            # Update existing talent
            if ranked
              # For archetype talents, add to the base rating of 1
              new_rating = is_archetype_talent ? (1 + rank - 1) : rank
              existing.update(rating: new_rating)
            end
          else
            # Create new talent
            FfgTalent.create(
              character: char,
              name: name,
              tier: tier,
              ranked: ranked,
              rating: ranked ? rank : 1
            )
          end
        end
      rescue => e
        Global.logger.error "FFG: Error saving talents for #{char.name}: #{e}"
        Global.logger.error e.backtrace.join("\n")
        errors << "There was a problem saving your talents. Please try again or contact staff."
      end

      # Handle Force powers (only for Force users)
      if Ffg.is_force_user?(char)
        force_powers = ffg[:force_powers] || ffg['force_powers'] || []

        Global.logger.debug "FFG: Processing #{force_powers.length} force powers"
        begin
          # Clear existing force powers
          char.ffg_force_powers.to_a.each { |p| p.delete }

          # Add force powers from chargen
          force_powers.each do |row|
            name = row[:name] || row['name']
            next if name.blank?

            config = Ffg.find_force_power_config(name)
            if !config
              Global.logger.warn "FFG: Unknown force power: #{name}"
              errors << "Unknown force power: #{name}"
              next
            end

            upgrades = Ffg.validate_force_power_upgrades(config, row[:upgrades] || row['upgrades'] || [], errors)

            FfgForcePower.create(
              character: char,
              name: config['name'],
              upgrades: upgrades
            )
          end
        rescue => e
          Global.logger.error "FFG: Error saving force powers for #{char.name}: #{e}"
          Global.logger.error e.backtrace.join("\n")
          errors << "There was a problem saving your force powers. Please try again or contact staff."
        end
      else
        # Dropping the force-using specialization gives up the powers that came with it,
        # otherwise they'd stay on the sheet and keep costing XP.
        char.ffg_force_powers.to_a.each { |p| p.delete }
      end

      # The web UI gates talent picks on the pyramid, but it's the client's copy of the
      # rules - re-check the tree we actually ended up with.
      if !Ffg.talent_tree_balanced?(char.ffg_talents.to_a)
        errors << t('ffg.talent_add_unbalanced')
      end

      # Update thresholds based on final characteristics
      if !char.is_approved?
        Ffg.update_thresholds(char)
      end

      # Reconcile XP.  The web UI tallies spending client-side for display; the sheet's
      # balance is always derived here from what actually got saved.
      starting_xp = Ffg.calculate_starting_xp(char)
      spent_xp = Ffg.calculate_spent_xp(char)
      char.update(ffg_xp: starting_xp - spent_xp)

      if spent_xp > starting_xp
        errors << t('ffg.not_enough_xp')
      end

      Global.logger.info "FFG: save_abilities completed for #{char.name} with #{errors.length} errors"
      errors
    end

    # Filters a submitted upgrade list down to the ones that are actually legal, appending
    # a message to `errors` for each one dropped.  Mirrors the checks in ForcePowerUpgradeCmd.
    def self.validate_force_power_upgrades(power_config, submitted, errors)
      upgrades_config = power_config['upgrades'] || []
      counts = {}
      known = []

      (submitted || []).each do |upgrade_name|
        upgrade_config = upgrades_config.select { |u| u['name'].downcase == upgrade_name.to_s.downcase }.first

        if !upgrade_config
          errors << t('ffg.invalid_upgrade')
          next
        end

        name = upgrade_config['name']
        max_rank = upgrade_config['max_rank'] || 1
        counts[name] = counts[name] || 0

        if counts[name] >= max_rank
          errors << t('ffg.upgrade_max_rank', :name => name, :max => max_rank)
          next
        end

        counts[name] += 1
        known << name
      end

      # Prereqs are checked against the whole submitted set so the order the UI happens to
      # send them in doesn't matter.
      known.select do |name|
        upgrade_config = upgrades_config.select { |u| u['name'] == name }.first
        prereq = upgrade_config['prereq']

        if prereq && !known.include?(prereq)
          errors << t('ffg.upgrade_needs_prereq', :upgrade => name, :prereq => prereq)
          false
        else
          true
        end
      end
    end

    # Extract the reset logic so both the command and web save can use it
    def self.perform_reset(char, archetype, career)
      Global.logger.info "FFG: Resetting #{char.name} to #{archetype}/#{career}"
      
      char.update(ffg_archetype: archetype)
      char.update(ffg_career: career)
      char.update(ffg_specializations: [])
      char.delete_ffg_abilities
      
      # Set archetype baseline
      config = Ffg.find_archetype_config(archetype)
      
      # Starting characteristics
      (config['characteristics'] || {}).each do |name, rating|
        Ffg.set_characteristic(char, name, rating)
      end
      
      # Starting skills
      (config['skills'] || []).each do |name|
        Ffg.set_skill(char, name, 1)
      end
      
      # Starting talents
      (config['talents'] || []).each do |name|
        talent_config = Ffg.find_talent_config(name)
        if talent_config
          FfgTalent.create(
            name: name, 
            character: char, 
            rating: 1,
            tier: talent_config['tier'] || 1,
            ranked: talent_config['ranked']
          )
        end
      end
      
      # Calculate starting XP
      bonus_xp = Global.read_config('ffg', 'bonus_xp') || 0
      career_xp = Global.read_config('ffg', 'career_skill_xp') || 0
      char.update(ffg_xp: config['xp'] + bonus_xp + career_xp)
      
      # Set career baseline skills (if any)
      career_config = Ffg.find_career_config(career)
      # Note: Most careers don't give free skills, but if yours does:
      # (career_config['skills'] || []).each do |name|
      #   Ffg.set_skill(char, name, 1)
      # end
      
      # Call customization hooks
      Ffg.set_archetype_bonuses(char, archetype)
      Ffg.set_career_bonuses(char, career)
      Ffg.update_thresholds(char)
      
      Global.logger.info "FFG: Reset complete for #{char.name}"
    end
  end
end