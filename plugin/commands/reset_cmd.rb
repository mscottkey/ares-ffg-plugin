module AresMUSH    
  module Ffg
    class ResetCmd
      include CommandHandler
      
      attr_accessor :type, :career
      
      def parse_args
        args = cmd.parse_args(ArgParser.arg1_slash_arg2)
        self.type = titlecase_arg args.arg1
        self.career = titlecase_arg args.arg2
      end
      
      def required_args
        [self.type, self.career]
      end
      
      def check_valid_values
        return t('ffg.invalid_archetype') if !Ffg.is_valid_archetype?(self.type)
        return t('ffg.invalid_career') if !Ffg.is_valid_career?(self.career)
        return nil
      end
      
      def check_chargen_locked
        return nil if Ffg.can_manage_abilities?(enactor)
        Chargen.check_chargen_locked(enactor)
      end
      
      def handle
        # Use the shared reset logic
        Ffg.perform_reset(enactor, self.type, self.career)
        client.emit_success t('ffg.archetype_set')
      end
    end
  end
end