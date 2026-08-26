module AresMUSH
  module Ffg
    # combat - shows the state of the combat in this room.
    class CombatCmd
      include CommandHandler

      def check_combat_exists
        return t('ffg.no_combat_here') if !Ffg.find_combat_for_room(enactor_room)
        return nil
      end

      def handle
        combat = Ffg.find_combat_for_room(enactor_room)
        client.emit CombatTemplate.new(combat).render
      end
    end
  end
end
