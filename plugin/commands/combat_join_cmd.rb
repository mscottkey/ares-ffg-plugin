module AresMUSH
  module Ffg
    # combat/join [<weapon>[/<armor>[/<range band>]]]
    class CombatJoinCmd
      include CommandHandler

      attr_accessor :weapon, :armor, :range_band

      def parse_args
        pieces = (cmd.args || "").split('/').map { |p| p.strip }
        self.weapon = titlecase_arg(pieces[0])
        self.armor = titlecase_arg(pieces[1])
        self.range_band = titlecase_arg(pieces[2])
      end

      def check_combat_exists
        return t('ffg.no_combat_here') if !Ffg.find_combat_for_room(enactor_room)
        return nil
      end

      def check_valid_weapon
        return nil if self.weapon.blank?
        return t('ffg.no_such_weapon') if !Ffg.find_weapon_config(self.weapon)
        return nil
      end

      def check_valid_armor
        return nil if self.armor.blank?
        return t('ffg.no_such_armor') if !Ffg.find_armor_config(self.armor)
        return nil
      end

      def check_valid_range_band
        return nil if self.range_band.blank?
        return t('ffg.no_such_range_band') if !Ffg.is_valid_range_band?(self.range_band)
        return nil
      end

      def handle
        combat = Ffg.find_combat_for_room(enactor_room)
        combatant = Ffg.add_pc_combatant(combat, enactor, self.weapon, self.armor, self.range_band)

        Rooms.emit_ooc_to_room enactor_room,
          t('ffg.joined_combat', :char => enactor_name, :weapon => combatant.weapon)
      end
    end
  end
end
