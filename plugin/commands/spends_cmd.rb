module AresMUSH
  module Ffg
    # spends [<roll id>] - what's still available to spend on a roll.
    class SpendsCmd
      include CommandHandler

      attr_accessor :roll_id

      def parse_args
        self.roll_id = trim_arg(cmd.args) || 'last'
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

        template = SpendsTemplate.new(roll)
        client.emit template.render
      end
    end
  end
end
