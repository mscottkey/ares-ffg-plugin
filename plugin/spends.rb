module AresMUSH
  module Ffg

    SPEND_SYMBOLS = [ 'advantage', 'threat', 'triumph', 'despair' ]

    # Whether the system applies mechanical results on its own.  A spend a player asks for
    # is always applied - this governs the results nobody chose, like the threat left over
    # on a roll.
    def self.auto_apply?
      (Global.read_config('ffg', 'automation') || 'suggest').to_s.downcase == 'auto'
    end

    def self.spend_configs(symbol)
      spends = Global.read_config('ffg', 'spends') || {}
      spends[symbol.to_s] || []
    end

    def self.find_spend_config(symbol, name)
      return nil if !name
      spend_configs(symbol).select { |s| s['name'].to_s.downcase == name.to_s.downcase }.first
    end

    # Looks a spend up across every symbol, so players can name one without saying which
    # symbol it comes from.  Returns [ symbol, config ] or nil.
    def self.find_spend_for_roll(roll, name)
      SPEND_SYMBOLS.each do |symbol|
        config = Ffg.find_spend_config(symbol, name)
        next if !config
        return [ symbol, config ] if Ffg.symbol_remaining(roll, symbol) >= (config['cost'] || 1)
      end

      # Nothing affordable - fall back to any match so the error can say why.
      SPEND_SYMBOLS.each do |symbol|
        config = Ffg.find_spend_config(symbol, name)
        return [ symbol, config ] if config
      end
      nil
    end

    def self.symbol_remaining(roll, symbol)
      case symbol.to_s
      when 'advantage' then roll.available_advantage
      when 'threat'    then roll.available_threat
      when 'triumph'   then roll.available_triumph
      when 'despair'   then roll.available_despair
      else 0
      end
    end

    # Every spend the roll can still afford, tagged with the symbol it comes from.
    def self.available_spends(roll)
      SPEND_SYMBOLS.flat_map do |symbol|
        remaining = Ffg.symbol_remaining(roll, symbol)
        next [] if remaining < 1

        Ffg.spend_configs(symbol).select { |s| (s['cost'] || 1) <= remaining }.map do |s|
          {
            'symbol'      => symbol,
            'name'        => s['name'],
            'cost'        => s['cost'] || 1,
            'target'      => s['target'] || 'self',
            'description' => s['description']
          }
        end
      end
    end

    def self.record_spend(roll, symbol, cost)
      case symbol.to_s
      when 'advantage' then roll.update(spent_advantage: (roll.spent_advantage || 0) + cost)
      when 'threat'    then roll.update(spent_threat: (roll.spent_threat || 0) + cost)
      when 'triumph'   then roll.update(spent_triumph: (roll.spent_triumph || 0) + cost)
      when 'despair'   then roll.update(spent_despair: (roll.spent_despair || 0) + cost)
      end
    end

    # Spends symbols off a roll and applies the effect.  Returns [ message, error ]; only
    # one of the two is ever set.
    def self.apply_spend(roll, symbol, spend_config, target = nil)
      cost = spend_config['cost'] || 1
      remaining = Ffg.symbol_remaining(roll, symbol)

      if remaining < cost
        return [ nil, t('ffg.not_enough_symbols', :symbol => symbol, :cost => cost, :have => remaining) ]
      end

      target_type = (spend_config['target'] || 'self').to_s

      case target_type
      when 'self'
        target = roll.character
      when 'none'
        target = nil
      else
        return [ nil, t('ffg.spend_needs_target', :name => spend_config['name']) ] if !target
      end

      Ffg.apply_spend_effect(spend_config, target)
      Ffg.record_spend(roll, symbol, cost)

      message = if target
        t('ffg.spend_applied_to', :name => spend_config['name'], :target => target.name, :symbol => symbol, :cost => cost)
      else
        t('ffg.spend_applied', :name => spend_config['name'], :symbol => symbol, :cost => cost)
      end

      [ message, nil ]
    end

    def self.apply_spend_effect(spend_config, target)
      return if !target

      amount = spend_config['amount'] || 1

      case spend_config['effect'].to_s
      when 'recover_strain'
        Ffg.change_strain(target, -amount)
      when 'suffer_strain'
        Ffg.change_strain(target, amount)
      when 'heal_wound'
        Ffg.change_wounds(target, -amount)
      when 'suffer_wound'
        Ffg.change_wounds(target, amount)
      when 'grant_boost'
        target.update(ffg_pending_boost: (target.ffg_pending_boost || 0) + amount)
      when 'grant_setback'
        target.update(ffg_pending_setback: (target.ffg_pending_setback || 0) + amount)
      when 'narrative', '', nil
        # Nothing to write - the spend is roleplayed out.
      else
        Global.logger.warn "FFG: Unknown spend effect: #{spend_config['effect']}"
      end
    end

    # Threat nobody chose to spend.  Only runs when the game is set to 'auto'.
    def self.auto_resolve_threat(roll)
      return [] if !Ffg.auto_apply?

      config = Ffg.spend_configs('threat').select { |s| s['auto'] }.first
      return [] if !config

      cost = config['cost'] || 1
      return [] if cost < 1

      messages = []
      while Ffg.symbol_remaining(roll, 'threat') >= cost
        message, error = Ffg.apply_spend(roll, 'threat', config, roll.character)
        break if error
        messages << message
      end
      messages
    end

    # ------------------------------------------------------------
    # Web data
    # ------------------------------------------------------------

    def self.build_web_roll_data(roll)
      {
        id: roll.id,
        roll_string: roll.roll_string,
        dice: roll.dice || [],
        successful: roll.successful,
        advantage: roll.available_advantage,
        threat: roll.available_threat,
        triumph: roll.available_triumph,
        despair: roll.available_despair,
        spends: Ffg.available_spends(roll)
      }
    end

    # A spend made from the web portal still happens in the scene, so say so in the room.
    def self.announce_spend(char, roll, message)
      room = char.room
      return if !room
      Rooms.emit_ooc_to_room room, "#{char.name}: #{message}"
    end

    # ------------------------------------------------------------
    # Wounds and strain
    # ------------------------------------------------------------
    # Every mechanical write to wounds and strain goes through here so it's clamped the
    # same way whatever caused it.  StatSetCmd stays the staff override for setting them
    # outright.

    def self.change_strain(char, amount)
      max = char.ffg_strain_threshold || 0
      current = char.ffg_strain || 0
      new_value = [ [ current + amount, 0 ].max, max ].min
      char.update(ffg_strain: new_value)
      new_value
    end

    def self.change_wounds(char, amount)
      max = char.ffg_wound_threshold || 0
      current = char.ffg_wounds || 0
      new_value = [ [ current + amount, 0 ].max, max ].min
      char.update(ffg_wounds: new_value)
      new_value
    end

    def self.incapacitated?(char)
      wound_max = char.ffg_wound_threshold || 0
      strain_max = char.ffg_strain_threshold || 0

      (wound_max > 0 && (char.ffg_wounds || 0) >= wound_max) ||
        (strain_max > 0 && (char.ffg_strain || 0) >= strain_max)
    end

  end
end
