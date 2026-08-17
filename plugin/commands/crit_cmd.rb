module AresMUSH
  module Ffg
    # crit <roll id>=<target> - spends advantage from an attack roll to inflict a critical.
    #
    # The cost is the attacking weapon's crit rating, taken off the recorded roll so the
    # same advantage can't be spent twice.
    class CritCmd
      include CommandHandler

      attr_accessor :roll_id, :target_name

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.roll_id = trim_arg(args.arg1)
        self.target_name = titlecase_arg(args.arg2)
      end

      def required_args
        [ self.roll_id, self.target_name ]
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

      def handle
        combat = Ffg.find_combat_for_room(enactor_room)
        attacker = Ffg.find_combatant(combat, enactor_name)
        defender = Ffg.find_combatant(combat, self.target_name)

        roll = if self.roll_id.downcase == 'last'
          Ffg.latest_roll(enactor)
        else
          Ffg.find_roll(enactor, self.roll_id)
        end

        if (!roll)
          client.emit_failure t('ffg.roll_not_found')
          return
        end

        weapon_config = Ffg.find_weapon_config(attacker.weapon) || Ffg.default_weapon_config
        cost = (weapon_config['crit'] || 3).to_i

        injury, error = Ffg.trigger_critical(roll, defender, cost)

        if (error)
          client.emit_failure error
          return
        end

        Rooms.emit_ooc_to_room enactor_room, t('ffg.crit_suffered',
          :attacker => enactor_name,
          :defender => defender.display_name,
          :cost => cost,
          :total => injury[:total],
          :name => injury[:name],
          :effect => injury[:effect])
      end
    end
  end
end
