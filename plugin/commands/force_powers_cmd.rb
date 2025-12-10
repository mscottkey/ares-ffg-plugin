module AresMUSH
  module Ffg
    class ForcePowersCmd
      include CommandHandler

      attr_accessor :search

      def parse_args
        self.search = trim_arg(cmd.args)
      end

      def handle
        if (self.search)
          # Show specific power details
          power_config = Ffg.find_force_power_config(self.search)
          if !power_config
            client.emit_failure t('ffg.invalid_force_power')
            return
          end

          template = ForcePowerDetailTemplate.new(power_config)
          client.emit template.render
        else
          # List all powers
          powers = Global.read_config('ffg', 'force_powers') || []
          template = ForcePowersTemplate.new(powers)
          client.emit template.render
        end
      end
    end
  end
end
