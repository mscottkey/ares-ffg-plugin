module AresMUSH
  module Ffg
    class ForcePowerUpgradeCmd
      include CommandHandler

      attr_accessor :power_name, :upgrade_name

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_slash_arg2)
        self.power_name = titlecase_arg(args.arg1)
        self.upgrade_name = titlecase_arg(args.arg2)
      end

      def required_args
        [ self.power_name, self.upgrade_name ]
      end

      def check_chargen_locked
        return nil if !enactor.is_approved?
        return t('ffg.cannot_change_after_approval')
      end

      def check_is_not_npc
        return t('dispatcher.not_allowed') if enactor.is_npc?
        return nil
      end

      def check_has_power
        power = Ffg.find_force_power(enactor, self.power_name)
        return t('ffg.dont_have_power') if !power
        return nil
      end

      def check_valid_upgrade
        power_config = Ffg.find_force_power_config(self.power_name)
        return t('ffg.invalid_force_power') if !power_config

        upgrades = power_config['upgrades'] || []
        upgrade = upgrades.select { |u| u['name'].downcase == self.upgrade_name.downcase }.first
        return t('ffg.invalid_upgrade') if !upgrade
        return nil
      end

      def handle
        power_config = Ffg.find_force_power_config(self.power_name)
        power = Ffg.find_force_power(enactor, self.power_name)

        upgrades_config = power_config['upgrades'] || []
        upgrade_config = upgrades_config.select { |u| u['name'].downcase == self.upgrade_name.downcase }.first

        xp_cost = upgrade_config['xp_cost'] || 5
        max_rank = upgrade_config['max_rank'] || 1
        prereq = upgrade_config['prereq']

        # Check current rank
        current_upgrades = power.upgrades || []
        current_rank = current_upgrades.count { |u| u == self.upgrade_name }

        if current_rank >= max_rank
          client.emit_failure t('ffg.upgrade_max_rank', :name => self.upgrade_name, :max => max_rank)
          return
        end

        # Check prerequisite
        if prereq && !current_upgrades.include?(prereq)
          client.emit_failure t('ffg.upgrade_needs_prereq', :upgrade => self.upgrade_name, :prereq => prereq)
          return
        end

        # Check XP
        available_xp = enactor.ffg_xp || 0
        if available_xp < xp_cost
          client.emit_failure t('ffg.not_enough_xp', :cost => xp_cost, :have => available_xp)
          return
        end

        # Add upgrade
        new_upgrades = current_upgrades + [self.upgrade_name]
        power.update(upgrades: new_upgrades)

        # Deduct XP
        new_xp = available_xp - xp_cost
        enactor.update(ffg_xp: new_xp)

        new_rank = current_rank + 1
        client.emit_success t('ffg.upgrade_added', :power => self.power_name, :upgrade => self.upgrade_name, :rank => new_rank, :cost => xp_cost)
      end
    end
  end
end
