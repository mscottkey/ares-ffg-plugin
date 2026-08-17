module AresMUSH
  module Ffg
    # spend <roll id>=<spend name>
    # spend <roll id>=<spend name>/<target>
    #
    # The roll id may be 'last' for your most recent roll.
    class SpendCmd
      include CommandHandler

      attr_accessor :roll_id, :spend_name, :target_name

      def parse_args
        args = cmd.parse_args(ArgParser.arg1_equals_arg2)
        self.roll_id = trim_arg(args.arg1)

        rest = args.arg2 || ""
        if (rest =~ /\//)
          self.spend_name = trim_arg(rest.before('/'))
          self.target_name = titlecase_arg(rest.after('/'))
        else
          self.spend_name = trim_arg(rest)
        end
      end

      def required_args
        [ self.roll_id, self.spend_name ]
      end

      def handle
        roll = if self.roll_id.downcase == 'last'
          Ffg.latest_roll(enactor)
        else
          Ffg.find_roll(enactor, self.roll_id)
        end

        if (!roll)
          client.emit_failure t('ffg.roll_not_found')
          return
        end

        found = Ffg.find_spend_for_roll(roll, self.spend_name)
        if (!found)
          client.emit_failure t('ffg.invalid_spend')
          return
        end

        symbol, spend_config = found

        if (self.target_name)
          ClassTargetFinder.with_a_character(self.target_name, client, enactor) do |target|
            self.apply(roll, symbol, spend_config, target)
          end
        else
          self.apply(roll, symbol, spend_config, nil)
        end
      end

      def apply(roll, symbol, spend_config, target)
        message, error = Ffg.apply_spend(roll, symbol, spend_config, target)

        if (error)
          client.emit_failure error
          return
        end

        Rooms.emit_ooc_to_room enactor_room, "#{enactor_name}: #{message}"
      end
    end
  end
end
