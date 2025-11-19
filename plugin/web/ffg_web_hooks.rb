module AresMUSH
  module Ffg
    class GetChargenInfoRequestHandler
      def handle(request)
        char = request.enactor
        error = Website.check_login(request)
        return error if error

        {
          char: Ffg.build_web_char_data(char, char, true),
          cg_ffg: Ffg.build_web_chargen_info
        }
      end
    end

    class SetArchetypeRequestHandler
      def handle(request)
        char = Character.find_one_by_name(request.args[:id])
        enactor = request.enactor
        
        error = Website.check_login(request)
        return error if error
        
        archetype = request.args[:archetype]
        
        if !Ffg.is_valid_archetype?(archetype)
          return { error: t('ffg.invalid_archetype') }
        end
        
        if !Ffg.can_manage_abilities?(enactor) && char != enactor
          return { error: t('dispatcher.not_allowed') }
        end
        
        if !Ffg.can_manage_abilities?(enactor)
          error = Chargen.check_chargen_locked(char)
          return { error: error } if error
        end
        
        # Reset character when changing archetype
        char.update(ffg_archetype: archetype)
        char.delete_ffg_abilities
        
        config = Ffg.find_archetype_config(archetype)
        (config['characteristics'] || {}).each do |name, rating|
          Ffg.set_characteristic(char, name, rating)
        end
        (config['skills'] || []).each do |name|
          Ffg.set_skill(char, name, 1)
        end
        (config['talents'] || []).each do |name|
          FfgTalent.create(name: name, character: char, rating: 1, tier: 1, ranked: false)
        end
        
        bonus_xp = Global.read_config('ffg', 'bonus_xp')
        career_xp = Global.read_config('ffg', 'career_skill_xp')
        char.update(ffg_xp: config['xp'] + bonus_xp + career_xp)
        
        Ffg.set_archetype_bonuses(char, archetype)
        Ffg.update_thresholds(char)
        
        {
          char: Ffg.build_web_char_data(char, char, true)
        }
      end
    end

    class SetCareerRequestHandler
      def handle(request)
        char = Character.find_one_by_name(request.args[:id])
        enactor = request.enactor
        
        error = Website.check_login(request)
        return error if error
        
        career = request.args[:career]
        
        if !Ffg.is_valid_career?(career)
          return { error: t('ffg.invalid_career') }
        end
        
        if !Ffg.can_manage_abilities?(enactor) && char != enactor
          return { error: t('dispatcher.not_allowed') }
        end
        
        if !Ffg.can_manage_abilities?(enactor)
          error = Chargen.check_chargen_locked(char)
          return { error: error } if error
        end
        
        char.update(ffg_career: career)
        
        config = Ffg.find_career_config(career)
        (config['skills'] || []).each do |name|
          existing = Ffg.find_skill(char, name)
          if !existing
            Ffg.set_skill(char, name, 1)
          end
        end
        
        Ffg.set_career_bonuses(char, career)
        
        {
          char: Ffg.build_web_char_data(char, char, true)
        }
      end
    end

    class AddSpecializationRequestHandler
      def handle(request)
        char = Character.find_one_by_name(request.args[:id])
        enactor = request.enactor
        
        error = Website.check_login(request)
        return error if error
        
        spec = request.args[:specialization]
        
        if !Ffg.is_valid_specialization?(spec)
          return { error: t('ffg.invalid_specialization') }
        end
        
        if !Ffg.can_manage_abilities?(enactor) && char != enactor
          return { error: t('dispatcher.not_allowed') }
        end
        
        if !Ffg.can_manage_abilities?(enactor) && !char.is_approved?
          error = Chargen.check_chargen_locked(char)
          return { error: error } if error
        end
        
        if char.ffg_specializations.include?(spec)
          return { error: t('ffg.already_have_spec') }
        end
        
        if char.ffg_specializations.count == 0 && !Ffg.is_career_specialization?(char, spec)
          return { error: t('ffg.first_spec_must_be_career') }
        end
        
        xp_cost = Ffg.specialization_xp_cost(char, spec, char.ffg_specializations.count)
        if xp_cost > char.ffg_xp
          return { error: t('ffg.not_enough_xp') }
        end
        
        char.update(ffg_xp: char.ffg_xp - xp_cost)
        
        specs = char.ffg_specializations
        specs << spec
        char.update(ffg_specializations: specs)
        
        Ffg.set_specialization_bonuses(char, spec)
        
        {
          char: Ffg.build_web_char_data(char, char, true)
        }
      end
    end

    class RemoveSpecializationRequestHandler
      def handle(request)
            char = Character.find_one_by_name(request.args[:id])
            enactor = request.enactor
            
            error = Website.check_login(request)
            return error if error
            
            spec = request.args[:specialization]
            
            if !Ffg.can_manage_abilities?(enactor) && char != enactor
            return { error: t('dispatcher.not_allowed') }
            end
            
            if !Ffg.can_manage_abilities?(enactor) && !char.is_approved?
            error = Chargen.check_chargen_locked(char)
            return { error: error } if error
            end
            
            if !char.ffg_specializations.include?(spec)
            return { error: t('ffg.dont_have_spec') }
            end
            
            if !Ffg.can_change_specs?(char)
            return { error: t('ffg.specs_locked_with_abilities') }
            end
            
            # Refund XP
            xp_cost = -Ffg.specialization_xp_cost(char, spec, char.ffg_specializations.count - 1)
            char.update(ffg_xp: char.ffg_xp - xp_cost)
            
            # Remove the spec
            specs = char.ffg_specializations
            specs.delete(spec)
            char.update(ffg_specializations: specs)
            
            {
            char: Ffg.build_web_char_data(char, char, true)
            }
        end
      end
  end
end