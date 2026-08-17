module AresMUSH
  module Ffg
    # attack <target>[=<weapon>]
    class AttackCmd
      include CommandHandler

      attr_accessor :target_name, :weapon

      def parse_args
        if (cmd.args =~ /\=/)
          args = cmd.parse_args(ArgParser.arg1_equals_arg2)
          self.target_name = titlecase_arg(args.arg1)
          self.weapon = titlecase_arg(args.arg2)
        else
          self.target_name = titlecase_arg(cmd.args)
        end
      end

      def required_args
        [ self.target_name ]
      end

      def check_combat_exists
        return t('ffg.no_combat_here') if !Ffg.find_combat_for_room(enactor_room)
        return nil
      end

      def check_attacker_in_combat
        combat = Ffg.find_combat_for_room(enactor_room)
        return t('ffg.not_in_combat') if !Ffg.find_combatant(combat, enactor_name)
        return nil
      end

      def check_target_in_combat
        combat = Ffg.find_combat_for_room(enactor_room)
        return t('ffg.target_not_in_combat', :name => self.target_name) if !Ffg.find_combatant(combat, self.target_name)
        return nil
      end

      def check_valid_weapon
        return nil if self.weapon.blank?
        return t('ffg.no_such_weapon') if !Ffg.find_weapon_config(self.weapon)
        return nil
      end

      def handle
        combat = Ffg.find_combat_for_room(enactor_room)
        attacker = Ffg.find_combatant(combat, enactor_name)
        defender = Ffg.find_combatant(combat, self.target_name)

        if (defender.incapacitated?)
          client.emit_failure t('ffg.target_already_down', :name => defender.display_name)
          return
        end

        result = Ffg.resolve_attack(combat, attacker, defender, self.weapon)

        if (result[:error])
          client.emit_failure result[:error]
          return
        end

        Rooms.emit_ooc_to_room enactor_room, Ffg.attack_message(result)
      end
    end
  end
end
