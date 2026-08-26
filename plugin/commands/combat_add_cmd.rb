module AresMUSH
  module Ffg
    # combat/add <name>=<tier>[/<count>[/<weapon>]] - adds an NPC to the combat.
    #
    # Minion groups take a count; their wound pool is sized by it.
    class CombatAddCmd
      include CommandHandler

      attr_accessor :npc_name, :tier, :minion_count, :weapon

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.npc_name = titlecase_arg(args.arg1)

        pieces = (args.arg2 || "").split('/').map { |p| p.strip }
        self.tier = pieces[0].blank? ? 'rival' : pieces[0].downcase
        self.minion_count = pieces[1].blank? ? 1 : pieces[1].to_i
        self.weapon = titlecase_arg(pieces[2])
      end

      def required_args
        [ self.npc_name ]
      end

      def check_can_manage
        return nil if Ffg.can_manage_abilities?(enactor)
        return t('dispatcher.not_allowed')
      end

      def check_combat_exists
        return t('ffg.no_combat_here') if !Ffg.find_combat_for_room(enactor_room)
        return nil
      end

      def check_valid_tier
        return t('ffg.no_such_tier', :tiers => Ffg.tier_names.join(', ')) if !Ffg.is_valid_tier?(self.tier)
        return nil
      end

      def check_valid_weapon
        return nil if self.weapon.blank?
        return t('ffg.no_such_weapon') if !Ffg.find_weapon_config(self.weapon)
        return nil
      end

      def check_name_not_taken
        combat = Ffg.find_combat_for_room(enactor_room)
        return t('ffg.combatant_already_here') if Ffg.find_combatant(combat, self.npc_name)
        return nil
      end

      def handle
        combat = Ffg.find_combat_for_room(enactor_room)

        combatant = Ffg.add_npc_combatant(combat, self.npc_name,
          tier: self.tier,
          minion_count: self.minion_count,
          weapon: self.weapon)

        Rooms.emit_ooc_to_room enactor_room, t('ffg.npc_joined_combat',
          :name => combatant.display_name,
          :tier => Ffg.adversary_tier_config(combatant.tier)['name'] || combatant.tier,
          :wounds => combatant.wound_threshold)
      end
    end
  end
end
