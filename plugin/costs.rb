module AresMUSH
  module Ffg
    def self.characteristic_xp_cost(char, old_rating, new_rating)
      cost = 0
      rating = old_rating
      while rating < new_rating
        rating = rating + 1
        cost = cost + (rating * 10)
      end
      cost
    end
    
    def self.skill_xp_cost(char, skill_name, old_rating, new_rating)
      is_career = Ffg.is_career_skill?(char, skill_name)
      cost = 0
      rating = old_rating
      while rating < new_rating
        rating = rating + 1
        cost = cost + (rating * 5) + (is_career ? 0 : 5)
      end
      cost
    end
    
    def self.specialization_xp_cost(char, spec, num_current_specs)
      if (num_current_specs == 0)
        return 0
      end
      is_career = Ffg.is_career_specialization?(char, spec)
      ((num_current_specs + 1) * 10) + (is_career ? 0 : 10)
    end
    
    def self.talent_xp_cost(talent, current_rating, new_rating)
      config = Ffg.find_talent_config(talent)
      tier = config['tier'] || 1
      cost = 0
      rating = current_rating
      while rating < new_rating
        cost = cost + (rating + tier) * 5
        rating = rating + 1
      end
      cost
    end

    def self.force_power_xp_cost(power_name, upgrades)
      config = Ffg.find_force_power_config(power_name)
      return 0 if !config

      cost = config['base_xp_cost'] || 10
      upgrades_config = config['upgrades'] || []

      (upgrades || []).each do |upgrade_name|
        upgrade_config = upgrades_config.select { |u| u['name'].downcase == upgrade_name.to_s.downcase }.first
        cost = cost + (upgrade_config ? (upgrade_config['xp_cost'] || 5) : 0)
      end
      cost
    end

    # How many talents occupy each tier.  A talent occupies its own tier, and a ranked
    # talent also occupies every tier up to its rating_plus_tier.
    def self.talent_tier_counts(talents)
      # to_a because Ohm collections count cardinality in Redis and won't take a block.
      list = talents.to_a
      counts = {}
      (1..5).each do |tier|
        counts[tier] = list.select { |t| (t.tier == tier) || (t.ranked && t.rating_plus_tier >= tier) }.count
      end
      counts
    end

    def self.talent_tree_balanced_for_add(char, tier)
      return true if tier == 1
      counts = Ffg.talent_tier_counts(char.ffg_talents)

      return (counts[tier - 1] > counts[tier] + 1)
    end

    def self.talent_tree_balanced_for_remove(char, tier)
      return true if char.ffg_talents.count == 1
      return true if tier == 5
      counts = Ffg.talent_tier_counts(char.ffg_talents)

      return (counts[tier] - 1) >= (counts[tier + 1] == 0 ? 0 : (counts[tier + 1] + 1))
    end

    # Whether a complete talent tree is balanced.  Each occupied tier must have strictly
    # fewer talents than the tier below it - the same invariant talent_tree_balanced_for_add
    # maintains one talent at a time.
    def self.talent_tree_balanced?(talents)
      counts = Ffg.talent_tier_counts(talents)
      (2..5).each do |tier|
        next if counts[tier] == 0
        return false if counts[tier - 1] <= counts[tier]
      end
      true
    end
  end
end