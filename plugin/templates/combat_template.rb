module AresMUSH
  module Ffg
    class CombatTemplate < ErbTemplateRenderer
      attr_accessor :combat

      def initialize(combat)
        @combat = combat
        super File.dirname(__FILE__) + "/combat.erb"
      end

      def round
        @combat.round || 0
      end

      def started?
        round > 0
      end

      def active_name
        active = @combat.active_combatant
        active ? active.display_name : nil
      end

      def combatants
        @combat.initiative_order
      end

      # A marker beside whoever's turn it is.
      def turn_marker(combatant)
        active_name == combatant.display_name ? '>' : ' '
      end

      def tier_name(combatant)
        Ffg.adversary_tier_config(combatant.tier)['name'] || combatant.tier.to_s.capitalize
      end

      def wounds(combatant)
        "#{combatant.wounds}/#{combatant.wound_threshold}"
      end

      def strain(combatant)
        return '-' if !Ffg.adversary_tier_config(combatant.tier)['uses_strain'] && !combatant.is_pc?
        "#{combatant.strain}/#{combatant.strain_threshold}"
      end

      def status(combatant)
        return t('ffg.combatant_down') if combatant.incapacitated?
        crits = combatant.crit_count || 0
        crits > 0 ? t('ffg.combatant_crits', :count => crits) : ''
      end

      def group(combatant)
        count = combatant.minion_count || 1
        count > 1 ? " x#{count}" : ''
      end
    end
  end
end
