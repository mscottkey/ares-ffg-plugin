module AresMUSH
  module Ffg
    class ApplyRollSpendRequestHandler
      def handle(request)
        char = request.enactor
        error = Website.check_login(request)
        return error if error

        roll = Ffg.find_roll(char, request.args[:roll_id])
        return { error: t('ffg.roll_not_found') } if !roll

        found = Ffg.find_spend_for_roll(roll, request.args[:spend])
        return { error: t('ffg.invalid_spend') } if !found

        symbol, spend_config = found
        target = nil

        target_name = request.args[:target]
        if (spend_config['target'].to_s == 'other')
          return { error: t('ffg.spend_needs_target', :name => spend_config['name']) } if target_name.blank?

          target = Character.find_one_by_name(target_name)
          return { error: t('db.object_not_found') } if !target
        end

        message, spend_error = Ffg.apply_spend(roll, symbol, spend_config, target)
        return { error: spend_error } if spend_error

        Ffg.announce_spend(char, roll, message)

        {
          message: message,
          roll: Ffg.build_web_roll_data(roll)
        }
      end
    end
  end
end
