module AresMUSH
  module Ffg
    class ForcePowerAddCmd
      include CommandHandler

      attr_accessor :name

      def parse_args
        self.name = trim_arg(cmd.args)
      end

      def required_args
        [ self.name ]
      end

      def check_chargen_locked
        return nil if !enactor.is_approved?
        return t('ffg.cannot_change_after_approval')
      end

      def check_is_not_npc
        return t('dispatcher.not_allowed') if enactor.is_npc?
        return nil
      end

      def check_force_user
        return nil if Ffg.is_force_user?(enactor)
        return t('ffg.must_be_force_user')
      end

      def check_valid_power
        return nil if Ffg.is_valid_force_power?(self.name)
        return t('ffg.invalid_force_power')
      end

      def check_already_has_power
        existing = Ffg.find_force_power(enactor, self.name)
        return t('ffg.already_has_power') if existing
        return nil
      end

      def check_xp_cost
        power_config = Ffg.find_force_power_config(self.name)
        base_cost = power_config['base_xp_cost'] || 10

        available_xp = enactor.ffg_xp || 0
        return nil if available_xp >= base_cost
        return t('ffg.not_enough_xp', :cost => base_cost, :have => available_xp)
      end

      def handle
        power_config = Ffg.find_force_power_config(self.name)
        base_cost = power_config['base_xp_cost'] || 10

        FfgForcePower.create(
          character: enactor,
          name: self.name,
          upgrades: []
        )

        # Deduct XP
        new_xp = (enactor.ffg_xp || 0) - base_cost
        enactor.update(ffg_xp: new_xp)

        client.emit_success t('ffg.force_power_added', :name => self.name, :cost => base_cost)
      end
    end
  end
end
