module AresMUSH
  module Ffg
    class ForcePowersTemplate < ErbTemplateRenderer
      attr_accessor :powers

      def initialize(powers)
        @powers = powers.sort_by { |p| p['name'] }
        super File.dirname(__FILE__) + "/force_powers.erb"
      end

      def name(power)
        power['name']
      end

      def description(power)
        power['description']
      end

      def base_cost(power)
        power['base_xp_cost'] || 10
      end
    end

    class ForcePowerDetailTemplate < ErbTemplateRenderer
      attr_accessor :power

      def initialize(power)
        @power = power
        super File.dirname(__FILE__) + "/force_power_detail.erb"
      end

      def name
        @power['name']
      end

      def description
        @power['description']
      end

      def base_cost
        @power['base_xp_cost'] || 10
      end

      def upgrades
        (@power['upgrades'] || []).map do |upgrade|
          cost = upgrade['xp_cost'] || 5
          max_rank = upgrade['max_rank'] || 1
          prereq = upgrade['prereq'] ? " (Requires: #{upgrade['prereq']})" : ""
          rank_text = max_rank > 1 ? " [Max Rank: #{max_rank}]" : ""

          "%xh#{upgrade['name']}%xn (#{cost} XP)#{rank_text}#{prereq}%r" +
          "  #{upgrade['description']}"
        end
      end
    end
  end
end
