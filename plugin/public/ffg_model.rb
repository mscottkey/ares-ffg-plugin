module AresMUSH
  class Character < Ohm::Model
    collection :ffg_skills, "AresMUSH::FfgSkill"
    collection :ffg_characteristics, "AresMUSH::FfgCharacteristic"
    collection :ffg_talents, "AresMUSH::FfgTalent"
    collection :ffg_force_powers, "AresMUSH::FfgForcePower"
    collection :ffg_rolls, "AresMUSH::FfgRoll"

    attribute :ffg_xp, :type => DataType::Integer
    attribute :ffg_story_points, :type => DataType::Integer
    attribute :ffg_force_rating, :type => DataType::Integer
    attribute :ffg_wound_threshold, :type => DataType::Integer
    attribute :ffg_strain_threshold, :type => DataType::Integer
    attribute :ffg_wounds, :type => DataType::Integer
    attribute :ffg_strain, :type => DataType::Integer
    
    attribute :ffg_career
    attribute :ffg_archetype
    attribute :ffg_specializations, :type => DataType::Array, :default => []

    # Boost/setback dice handed to this character by someone else's advantage or threat,
    # consumed by their next roll.
    attribute :ffg_pending_boost, :type => DataType::Integer
    attribute :ffg_pending_setback, :type => DataType::Integer

    before_delete :delete_ffg_abilities
    before_delete :delete_ffg_rolls
    
    def delete_ffg_abilities
      [ self.ffg_skills, self.ffg_characteristics, self.ffg_talents, self.ffg_force_powers ].each do |list|
        list.each do |a|
          a.delete
        end
      end
    end

    # Rolls aren't abilities - a chargen reset shouldn't wipe them - so they're only
    # cleaned up when the character goes away.
    def delete_ffg_rolls
      self.ffg_rolls.each { |r| r.delete }
    end
  end
  
  class FfgSkill < Ohm::Model
    include ObjectModel
    
    attribute :name
    attribute :rating, :type => DataType::Integer
    reference :character, "AresMUSH::Character"
    index :name    
  end
  
  class FfgCharacteristic < Ohm::Model
    include ObjectModel
    
    attribute :name
    attribute :rating, :type => DataType::Integer
    reference :character, "AresMUSH::Character"
    index :name
  end
  
  class FfgTalent < Ohm::Model
    include ObjectModel

    attribute :name
    attribute :rating, :type => DataType::Integer
    attribute :ranked, :type => DataType::Boolean
    attribute :tier, :type => DataType::Integer
    attribute :specialization
    reference :character, "AresMUSH::Character"
    index :name

    def rating_plus_tier
      self.rating > 1 ? self.tier + self.rating - 1 : self.tier
    end
  end

  class FfgForcePower < Ohm::Model
    include ObjectModel

    attribute :name
    attribute :upgrades, :type => DataType::Array, :default => []
    reference :character, "AresMUSH::Character"
    index :name
  end

  # A resolved roll, kept so the advantage and threat it generated can be spent after
  # the fact instead of just being printed and forgotten.
  class FfgRoll < Ohm::Model
    include ObjectModel

    attribute :roll_string
    attribute :dice, :type => DataType::Array, :default => []
    attribute :successful, :type => DataType::Boolean
    attribute :net_advantage, :type => DataType::Integer, :default => 0
    attribute :net_threat, :type => DataType::Integer, :default => 0
    attribute :triumph, :type => DataType::Boolean
    attribute :despair, :type => DataType::Boolean
    attribute :spent_advantage, :type => DataType::Integer, :default => 0
    attribute :spent_threat, :type => DataType::Integer, :default => 0
    attribute :spent_triumph, :type => DataType::Integer, :default => 0
    attribute :spent_despair, :type => DataType::Integer, :default => 0
    attribute :created_at, :type => DataType::Integer
    attribute :scene_id

    reference :character, "AresMUSH::Character"
    index :scene_id

    def available_advantage
      (self.net_advantage || 0) - (self.spent_advantage || 0)
    end

    def available_threat
      (self.net_threat || 0) - (self.spent_threat || 0)
    end

    def available_triumph
      (self.triumph ? 1 : 0) - (self.spent_triumph || 0)
    end

    def available_despair
      (self.despair ? 1 : 0) - (self.spent_despair || 0)
    end

    def anything_to_spend?
      available_advantage > 0 || available_threat > 0 ||
        available_triumph > 0 || available_despair > 0
    end

    def print_dice
      (self.dice || []).join(" ")
    end
  end


end