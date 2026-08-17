module AresMUSH
  module Ffg
    # combat/end - closes the combat and clears its combatants.
    class CombatEndCmd
      include CommandHandler

      def check_can_manage
        return nil if Ffg.can_manage_abilities?(enactor)
        return t('dispatcher.not_allowed')
      end

      def check_combat_exists
        return t('ffg.no_combat_here') if !Ffg.find_combat_for_room(enactor_room)
        return nil
      end

      def handle
        combat = Ffg.find_combat_for_room(enactor_room)
        Ffg.end_combat(combat)

        Rooms.emit_ooc_to_room enactor_room, t('ffg.combat_ended', :char => enactor_name)
      end
    end
  end
end
