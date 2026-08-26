module AresMUSH
  module Ffg
    # combat/next - hands the turn to the next combatant in the initiative order.
    class CombatNextCmd
      include CommandHandler

      def check_combat_exists
        return t('ffg.no_combat_here') if !Ffg.find_combat_for_room(enactor_room)
        return nil
      end

      def check_initiative_rolled
        combat = Ffg.find_combat_for_room(enactor_room)
        return t('ffg.initiative_not_rolled') if (combat.round || 0) < 1
        return nil
      end

      def handle
        combat = Ffg.find_combat_for_room(enactor_room)
        combatant = Ffg.advance_turn(combat)

        return if !combatant

        Rooms.emit_ooc_to_room enactor_room, t('ffg.turn_advanced',
          :round => combat.round,
          :name => combatant.display_name)
      end
    end
  end
end
