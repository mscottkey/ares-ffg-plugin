module AresMUSH
  module Ffg
    class ResetAbilitiesRequestHandler
      def handle(request)
        char = request.enactor
        error = Website.check_login(request)
        return error if error
        
        # Can't reset after approval
        if char.is_approved?
          return { error: t('chargen.cannot_reset_after_approved') }
        end
        
        archetype = request.args[:archetype]
        career = request.args[:career]
        
        # Validate
        if !Ffg.is_valid_archetype?(archetype)
          return { error: t('ffg.invalid_archetype') }
        end
        
        if !Ffg.is_valid_career?(career)
          return { error: t('ffg.invalid_career') }
        end
        
        # Perform the reset
        Ffg.perform_reset(char, archetype, career)
        
        # Return the updated character data
        {
          id: char.id,
          char: Ffg.build_web_char_data(char, char, true)
        }
      end
    end
  end
end