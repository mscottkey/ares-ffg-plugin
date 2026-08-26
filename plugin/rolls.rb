module AresMUSH
  module Ffg

    class FfgRollParams
      attr_accessor :boost, :ability, :proficiency, :setback, :difficulty, :challenge, :force, :skill
      attr_accessor :upgrade_ability, :upgrade_difficulty

      def initialize
        self.boost = 0
        self.ability = 0
        self.proficiency = 0
        self.setback = 0
        self.difficulty = 0
        self.challenge = 0
        self.force = 0
        self.skill = nil
        self.upgrade_ability = 0
        self.upgrade_difficulty = 0
      end
    end

    class FfgRollResults
      attr_accessor :successful, :net_advantage, :net_threat, :despair, :triumph
    end

    # Returns a FfgRollParams object
    def self.parse_roll_string(roll_str)
      params = FfgRollParams.new
      sections = roll_str.split(/([\+-]\d+\w+)/)
      sections.each do |s|
        s = s.strip.titlecase.gsub("+", "")
        next if s.blank?

        # The two-letter upgrade codes are checked first so their trailing letter isn't
        # mistaken for a die code.
        if (s =~ /([-\d]+)ua/i)
          params.upgrade_ability += $1.to_i
        elsif (s =~ /([-\d]+)ud/i)
          params.upgrade_difficulty += $1.to_i
        elsif (s =~ /([-\d]+)b/i)
          params.boost += $1.to_i
        elsif (s =~ /([-\d]+)a/i)
          params.ability += $1.to_i
        elsif (s =~ /([-\d]+)p/i)
          params.proficiency += $1.to_i
        elsif (s =~ /([-\d]+)s/i)
          params.setback += $1.to_i
        elsif (s =~ /([-\d]+)d/i)
          params.difficulty += $1.to_i
        elsif (s =~ /([-\d]+)c/i)
          params.challenge += $1.to_i
        elsif (s =~ /([-\d]+)f/i)
          params.force += $1.to_i
        else
          config = Ffg.find_skill_config(s)
          return nil if !config
          params.skill = s
        end
      end
      params
    end

    # Upgrading turns a die into its stronger form - ability into proficiency, difficulty
    # into challenge.  With nothing left to upgrade, an upgrade adds a basic die instead;
    # a downgrade with nothing to downgrade removes one.  Returns [basic, upgraded].
    def self.apply_upgrades(count, basic, upgraded)
      count.abs.times do
        if (count > 0)
          if (basic > 0)
            basic = basic - 1
            upgraded = upgraded + 1
          else
            basic = basic + 1
          end
        else
          if (upgraded > 0)
            upgraded = upgraded - 1
            basic = basic + 1
          elsif (basic > 0)
            basic = basic - 1
          end
        end
      end
      [ basic, upgraded ]
    end
    
    # Returns a FfgRollResults object
    def self.roll_ability(char, roll_str)
      params = Ffg.parse_roll_string(roll_str)
      return nil if !params
      
      dice = []
      
      if (params.skill)
        skill_dice = Ffg.find_skill_dice(char, params.skill)

        params.ability += skill_dice[:ability]
        params.proficiency += skill_dice[:proficiency]
      end

      # Upgrades act on the finished pool, so they're applied after the skill dice.
      params.ability, params.proficiency =
        Ffg.apply_upgrades(params.upgrade_ability, params.ability, params.proficiency)
      params.difficulty, params.challenge =
        Ffg.apply_upgrades(params.upgrade_difficulty, params.difficulty, params.challenge)

      params.boost.times.each do |d|
        dice << Ffg.roll_boost_die
      end
      params.ability.times.each do |d|
        dice << Ffg.roll_ability_die
      end
      params.proficiency.times.each do |d|
        dice << Ffg.roll_proficiency_die
      end
      params.setback.times.each do |d|
        dice << Ffg.roll_setback_die
      end
      params.difficulty.times.each do |d|
        dice << Ffg.roll_difficulty_die
      end
      params.challenge.times.each do |d|
        dice << Ffg.roll_challenge_die
      end
      params.force.times.each do |d|
        dice << Ffg.roll_force_die
      end
      
      Global.logger.info "Rolling #{params.inspect} - #{dice}."
      dice.flatten.sort
    end
    
    def self.find_skill_dice(char, skill)
      skill_rating = Ffg.skill_rating(char, skill)
      charac_rating = Ffg.related_characteristic_rating(char, skill)
      
      if (skill_rating > charac_rating)
        ability_dice = skill_rating - charac_rating
        prof_dice = charac_rating
      else
        ability_dice = charac_rating - skill_rating
        prof_dice = skill_rating
      end
      {
        ability: ability_dice,
        proficiency: prof_dice
      }
    end
    
    def self.related_characteristic_rating(char, skill)
      skill_config = Ffg.find_skill_config(skill)
      return 0 if !skill_config
      Ffg.characteristic_rating(char, skill_config['characteristic'])
    end
      
    def self.determine_outcome(dice)
      successes = dice.select { |d| d == 'S' || d == 'TRI' }.count
      failures = dice.select { |d| d == 'F' || d == 'DES' }.count
      
      adv = dice.select { |d| d == 'A' }.count
      threat = dice.select { |d| d == 'T' }.count
      
      results = FfgRollResults.new
      results.successful = successes > failures
      results.triumph = dice.any? { |d| d == 'TRI' }
      results.despair = dice.any? { |d| d == 'DES' }
      results.net_advantage = adv > threat ? adv - threat : 0
      results.net_threat = threat > adv ? threat - adv : 0
      
      results
    end
    
    # Rolls, resolves and records a check.  Returns the saved FfgRoll, or nil if the roll
    # string didn't parse.  This is the entry point commands and web handlers should use -
    # roll_ability itself stays a pure dice roll.
    def self.make_roll(char, roll_str, scene_id = nil)
      pending_boost = char.ffg_pending_boost || 0
      pending_setback = char.ffg_pending_setback || 0

      full_roll_str = roll_str.to_s
      full_roll_str = "#{full_roll_str}+#{pending_boost}B" if pending_boost > 0
      full_roll_str = "#{full_roll_str}+#{pending_setback}S" if pending_setback > 0

      dice = Ffg.roll_ability(char, full_roll_str)
      return nil if !dice

      # Only consume the pending dice once we know the roll was actually made.
      char.update(ffg_pending_boost: 0) if pending_boost > 0
      char.update(ffg_pending_setback: 0) if pending_setback > 0

      results = Ffg.determine_outcome(dice)

      Ffg.prune_roll_history(char)

      roll = FfgRoll.create(
        character: char,
        roll_string: full_roll_str,
        dice: dice,
        successful: results.successful,
        net_advantage: results.net_advantage,
        net_threat: results.net_threat,
        triumph: results.triumph,
        despair: results.despair,
        spent_advantage: 0,
        spent_threat: 0,
        spent_triumph: 0,
        spent_despair: 0,
        created_at: Time.now.to_i,
        scene_id: scene_id
      )

      # In 'auto' games leftover threat resolves itself; in 'suggest' games it waits for
      # someone to decide what it means.
      Ffg.auto_resolve_threat(roll)

      roll
    end

    def self.roll_message(char_name, roll)
      special = Ffg.special_roll_effects(roll)
      special = "#{special}#{t('ffg.roll_spend_hint', :id => roll.id)}" if roll.anything_to_spend?

      key = roll.successful ? 'ffg.roll_successful' : 'ffg.roll_failed'
      t(key, :dice => roll.print_dice, :special => special, :roll => roll.roll_string, :char => char_name)
    end

    def self.find_roll(char, roll_id)
      char.ffg_rolls.to_a.select { |r| r.id.to_s == roll_id.to_s }.first
    end

    def self.latest_roll(char)
      char.ffg_rolls.to_a.sort_by { |r| r.created_at || 0 }.last
    end

    def self.prune_roll_history(char)
      hours = Global.read_config('ffg', 'roll_history_hours') || 24
      cutoff = Time.now.to_i - (hours * 3600)

      char.ffg_rolls.to_a.each do |roll|
        roll.delete if (roll.created_at || 0) < cutoff
      end
    end

    def self.special_roll_effects(results)
      special = ""
      
      if (results.net_advantage > 0)
        special << "#{t('ffg.roll_advantage', :net => results.net_advantage)} "
      end
      if (results.net_threat > 0)
        special << "#{t('ffg.roll_threat', :net => results.net_threat)} "
      end
      if (results.triumph)
        special << "#{t('ffg.roll_triumph')} "
      end
      if (results.despair)
        special << "#{t('ffg.roll_despair')} "
      end
      special
    end
    
    def self.roll_boost_die
      [ ['-'], ['-'], ['S'], [ 'S', 'A' ], [ 'A', 'A' ], [ 'A' ] ].shuffle.first
    end
    
    def self.roll_ability_die
      [ ['-'], ['S'], ['S'], [ 'S', 'S' ], [ 'A' ], [ 'A' ], [ 'S', 'A' ], [ 'A', 'A' ] ].shuffle.first
    end
    
    def self.roll_proficiency_die
      [ ['-'], ['S'], ['S'], [ 'S', 'S' ], [ 'S', 'S' ], [ 'A' ], [ 'S', 'A' ], [ 'S', 'A' ], [ 'S', 'A' ], [ 'A', 'A'], [ 'A', 'A' ], [ 'TRI' ]].shuffle.first
    end
    
    def self.roll_setback_die
      [ ['-'], ['-'], ['F'], [ 'F' ], [ 'T' ], [ 'T' ] ].shuffle.first
    end
    
    def self.roll_difficulty_die
      [ ['-'], ['F'], ['F', 'F'], ['T'], [ 'T' ], [ 'T' ], [ 'T', 'T' ], [ 'F', 'T' ] ].shuffle.first
    end
    
    def self.roll_challenge_die
      [ ['-'], ['F'], ['F'], [ 'F', 'F' ], [ 'F', 'F' ], [ 'T' ], [ 'T' ], [ 'F', 'T' ], [ 'F', 'T' ], [ 'T', 'T'], [ 'T', 'T' ], [ 'DES' ]].shuffle.first
    end
    
    def self.roll_force_die
      [ ['Dark'], ['Dark'], ['Dark'], ['Dark'], ['Dark'], ['Dark'], ['Dark', 'Dark'], ['Light'], ['Light'], ['Light', 'Light'], ['Light', 'Light'], ['Light', 'Light'] ].shuffle.first
    end
    
  end
end