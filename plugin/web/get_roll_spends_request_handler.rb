module AresMUSH
  module Ffg
    # Returns the enactor's recent rolls that still have symbols left to spend.
    class GetRollSpendsRequestHandler
      def handle(request)
        char = request.enactor
        error = Website.check_login(request)
        return error if error

        rolls = char.ffg_rolls.to_a
          .select { |r| r.anything_to_spend? }
          .sort_by { |r| r.created_at || 0 }
          .reverse

        {
          rolls: rolls.map { |roll| Ffg.build_web_roll_data(roll) }
        }
      end
    end
  end
end
