module AresMUSH
  module Ffg
    class ResolveAttackRequestHandler
      def handle(request)
        char = request.enactor
        error = Website.check_login(request)
        return error if error

        combat = Ffg.find_combat_for_room(char.room)
        return { error: t('ffg.no_combat_here') } if !combat

        attacker = Ffg.find_combatant(combat, char.name)
        return { error: t('ffg.not_in_combat') } if !attacker

        defender = Ffg.find_combatant(combat, request.args[:target])
        if !defender
          return { error: t('ffg.target_not_in_combat', :name => request.args[:target]) }
        end

        if defender.incapacitated?
          return { error: t('ffg.target_already_down', :name => defender.display_name) }
        end

        weapon = request.args[:weapon]
        if !weapon.blank? && !Ffg.find_weapon_config(weapon)
          return { error: t('ffg.no_such_weapon') }
        end

        result = Ffg.resolve_attack(combat, attacker, defender, weapon)
        return { error: result[:error] } if result[:error]

        message = Ffg.attack_message(result)
        Rooms.emit_ooc_to_room char.room, message

        {
          message: message,
          roll_id: result[:roll].id,
          hit: result[:hit],
          damage: result[:damage],
          soak: result[:soak],
          wounds: result[:wounds_dealt],
          applied: result[:applied],
          crit_available: result[:crit_available],
          crit_cost: result[:crit_cost],
          combat: Ffg.build_web_combat_data(combat, char)
        }
      end
    end
  end
end
