module AresMUSH    
  module Ffg
    class RollCmd
      include CommandHandler
      
      attr_accessor :roll_str
  
      def parse_args
         self.roll_str = trim_arg(cmd.args)
      end
      
      def required_args
        [ self.roll_str ]
      end
      
      
      def handle
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