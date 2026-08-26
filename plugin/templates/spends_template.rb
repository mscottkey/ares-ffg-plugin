module AresMUSH
  module Ffg
    class SpendsTemplate < ErbTemplateRenderer
      attr_accessor :roll

      def initialize(roll)
        @roll = roll
        super File.dirname(__FILE__) + "/spends.erb"
      end

      def roll_id
        @roll.id
      end

      def roll_string
        @roll.roll_string
      end

      def dice
        @roll.print_dice
      end

      def remaining
        SPEND_SYMBOLS.map do |symbol|
          count = Ffg.symbol_remaining(@roll, symbol)
          next nil if count < 1
          "#{symbol.capitalize} (#{count})"
        end.compact.join("  ")
      end

      def spends
        Ffg.available_spends(@roll)
      end

      def target_note(spend)
        spend['target'].to_s == 'other' ? " (needs a target)" : ""
      end
    end
  end
end
