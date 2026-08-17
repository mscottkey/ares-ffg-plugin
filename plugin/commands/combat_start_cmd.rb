module AresMUSH
  module Ffg
    # combat/start - opens a combat in the current room.
    class CombatStartCmd
      include CommandHandler

      def check_not_already_started
        return t('ffg.combat_already_started') if Ffg.find_combat_for_room(enactor_room)
        return nil
      end

      def handle
        Ffg.start_combat(enactor_room, Ffg.current_scene_id(enactor))
        Rooms.emit_ooc_to_room enactor_room, t('ffg.combat_started', :char => enactor_name)
      end
    end
  end
end
