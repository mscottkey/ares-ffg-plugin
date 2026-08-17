module AresMUSH
  module Ffg
    # combat/initiative - rolls initiative for everyone and starts round 1.
    class CombatInitiativeCmd
      include CommandHandler

      def check_can_manage
        return nil if Ffg.can_manage_abilities?(enactor)
        return t('dispatcher.not_allowed')
      end

      def check_combat_exists
        return t('ffg.no_combat_here') if !Ffg.find_combat_for_room(enactor_room)
        return nil
      end

      def check_has_combatants
        combat = Ffg.find_combat_for_room(enactor_room)
        return t('ffg.no_combatants') if combat.combatants.to_a.empty?
        return nil
      end

      def handle
        combat = Ffg.find_combat_for_room(enactor_room)
        order = Ffg.roll_initiative(combat)

        Rooms.emit_ooc_to_room enactor_room, t('ffg.initiative_rolled',
          :order => order.map { |c| c.display_name }.join(', '))

        client.emit CombatTemplate.new(combat).render
      end
    end
  end
end
