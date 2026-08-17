module AresMUSH    
  module Ffg
    class RollOpposedCmd
      include CommandHandler
      
      attr_accessor :roll_str, :opponent, :vs_ability
  
      def parse_args
        if (cmd.args)
         self.roll_str = cmd.args.before(' vs ')
         post_str = cmd.args.after(' vs ') || ""
         self.opponent = post_str.before('/')
         self.vs_ability = post_str.after('/')
       end
      end
      
      def required_args
        [ self.roll_str, self.opponent, self.vs_ability ]
      end
      
      
      def handle
        ClassTargetFinder.with_a_character(self.opponent, client, enactor) do |model|          
          if (!Ffg.is_valid_skill_name?(self.vs_ability))
            client.emit_failure t('ffg.invalid_ability_name')
            return
          end
          
          skill = Ffg.skill_rating(model, self.vs_ability)
          charac = Ffg.related_characteristic_rating(model, self.vs_ability)
          
          if (skill > charac)
            challenge = skill - charac
            difficulty = charac
          else
            challenge = charac - skill
            difficulty = skill
          end
          
          self.roll_str = "#{self.roll_str}+#{challenge}C+#{difficulty}D"

          roll = Ffg.make_roll(enactor, self.roll_str, Ffg.current_scene_id(enactor))

          if (!roll)
            client.emit_failure t('ffg.invalid_ability_name')
            return
          end

          Rooms.emit_ooc_to_room enactor_room, Ffg.roll_message(enactor_name, roll)
        end
      end
    end
  end
end