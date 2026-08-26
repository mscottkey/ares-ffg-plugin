module AresMUSH
  module Ffg
    # Returns the combat in the enactor's room, if there is one.
    class GetCombatRequestHandler
      def handle(request)
        char = request.enactor
        error = Website.check_login(request)
        return error if error

        combat = Ffg.find_combat_for_room(char.room)
        return { combat: nil } if !combat

        { combat: Ffg.build_web_combat_data(combat, char) }
      end
    end
  end
end
