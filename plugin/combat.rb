module AresMUSH
  module Ffg

    # ------------------------------------------------------------
    # Config lookups
    # ------------------------------------------------------------

    def self.find_weapon_config(name)
      return nil if !name
      weapons = Global.read_config('ffg', 'weapons') || []
      weapons.select { |w| w['name'].to_s.downcase == name.to_s.downcase }.first
    end

    def self.find_armor_config(name)
      return nil if !name
      armor = Global.read_config('ffg', 'armor') || []
      armor.select { |a| a['name'].to_s.downcase == name.to_s.downcase }.first
    end

    def self.default_weapon_config
      Ffg.find_weapon_config('Unarmed') || (Global.read_config('ffg', 'weapons') || []).first
    end

    def self.range_bands
      Global.read_config('ffg', 'range_bands') || [ 'Engaged', 'Short', 'Medium', 'Long', 'Extreme' ]
    end

    def self.adversary_tier_config(tier)
      tiers = Global.read_config('ffg', 'adversary_tiers') || {}
      tiers[tier.to_s.downcase] || {}
    end

    def self.is_valid_range_band?(band)
      return false if !band
      Ffg.range_bands.any? { |b| b.downcase == band.to_s.downcase }
    end

    def self.is_valid_tier?(tier)
      return false if !tier
      (Global.read_config('ffg', 'adversary_tiers') || {}).key?(tier.to_s.downcase)
    end

    def self.tier_names
      (Global.read_config('ffg', 'adversary_tiers') || {}).keys
    end

    # ------------------------------------------------------------
    # Combat lifecycle
    # ------------------------------------------------------------

    def self.find_combat_for_room(room)
      return nil if !room
      FfgCombat.find(room_id: room.id.to_s).first
    end

    def self.start_combat(room, scene_id = nil)
      existing = Ffg.find_combat_for_room(room)
      return existing if existing

      FfgCombat.create(
        room_id: room.id.to_s,
        scene_id: scene_id,
        round: 0,
        turn_index: 0
      )
    end

    def self.end_combat(combat)
      # NPC rolls belong to the combat rather than to a character, so nothing else would
      # ever clean them up.
      FfgRoll.find(combat_id: combat.id.to_s).each { |roll| roll.delete }

      combat.delete_combatants
      combat.delete
    end

    def self.find_combatant(combat, name)
      return nil if !name
      combat.combatants.to_a.select { |c| c.display_name.to_s.downcase == name.to_s.downcase }.first
    end

    def self.add_pc_combatant(combat, char, weapon = nil, armor = nil, range_band = nil)
      existing = Ffg.find_combatant(combat, char.name)
      return existing if existing

      FfgCombatant.create(
        combat: combat,
        character: char,
        tier: 'nemesis',
        weapon: weapon || Ffg.default_weapon_config['name'],
        armor: armor || 'None',
        range_band: range_band || 'Engaged'
      )
    end

    # NPC combatants carry their own stats.  Minion groups share a wound pool sized by the
    # number of minions in the group.
    def self.add_npc_combatant(combat, name, opts = {})
      tier = (opts[:tier] || 'rival').to_s.downcase
      minion_count = (opts[:minion_count] || 1).to_i
      minion_count = 1 if minion_count < 1

      wound_threshold = (opts[:wound_threshold] || 10).to_i
      wound_threshold = wound_threshold * minion_count if Ffg.adversary_tier_config(tier)['shared_wounds']

      FfgCombatant.create(
        combat: combat,
        npc_name: name,
        tier: tier,
        weapon: opts[:weapon] || Ffg.default_weapon_config['name'],
        armor: opts[:armor] || 'None',
        range_band: opts[:range_band] || 'Engaged',
        npc_wounds: 0,
        npc_wound_threshold: wound_threshold,
        npc_strain: 0,
        npc_strain_threshold: (opts[:strain_threshold] || 10).to_i,
        npc_soak: (opts[:soak] || 2).to_i,
        npc_skill: (opts[:skill] || 1).to_i,
        minion_count: minion_count
      )
    end

    # ------------------------------------------------------------
    # Initiative
    # ------------------------------------------------------------

    def self.initiative_skill_for(combatant)
      skills = Global.read_config('ffg', 'initiative_skills') || [ 'Vigilance', 'Cool' ]
      return skills.last if !combatant.is_pc?

      skills.find { |s| Ffg.skill_rating(combatant.character, s) > 0 } || skills.last
    end

    def self.roll_initiative(combat)
      combat.combatants.to_a.each do |combatant|
        dice = if combatant.is_pc?
          skill = Ffg.initiative_skill_for(combatant)
          Ffg.roll_ability(combatant.character, skill) || []
        else
          # NPCs roll their skill rating straight, with no characteristic to draw on.
          Ffg.roll_ability(nil, "#{combatant.npc_skill || 1}A") || []
        end

        results = Ffg.determine_outcome(dice)
        successes = dice.select { |d| d == 'S' || d == 'TRI' }.count
        failures = dice.select { |d| d == 'F' || d == 'DES' }.count

        combatant.update(
          initiative: successes - failures,
          initiative_advantage: results.net_advantage
        )
      end

      combat.update(round: 1, turn_index: 0)
      combat.initiative_order
    end

    def self.advance_turn(combat)
      order = combat.initiative_order
      return nil if order.empty?

      next_index = (combat.turn_index || 0) + 1

      if next_index >= order.count
        combat.update(round: (combat.round || 1) + 1, turn_index: 0)
      else
        combat.update(turn_index: next_index)
      end

      combat.active_combatant
    end

    # ------------------------------------------------------------
    # Attacks
    # ------------------------------------------------------------

    # How many bands apart two combatants are.  Unknown bands count as adjacent so a
    # misconfigured band can't silently make an attack impossible.
    def self.range_penalty(attacker, weapon_config)
      bands = Ffg.range_bands.map { |b| b.downcase }
      target_band = (attacker.range_band || bands.first).to_s.downcase
      weapon_band = (weapon_config['range'] || bands.first).to_s.downcase

      target_index = bands.index(target_band)
      weapon_index = bands.index(weapon_band)
      return 0 if !target_index || !weapon_index

      # Only shooting past a weapon's range is penalized; closer is free.
      target_index > weapon_index ? target_index - weapon_index : 0
    end

    def self.range_difficulty(band)
      table = Global.read_config('ffg', 'range_difficulty') || {}
      match = table.keys.find { |k| k.to_s.downcase == band.to_s.downcase }
      match ? table[match].to_i : 1
    end

    def self.soak_for(combatant)
      armor_config = Ffg.find_armor_config(combatant.armor) || {}
      armor_soak = (armor_config['soak'] || 0).to_i

      if combatant.is_pc?
        brawn = Ffg.characteristic_rating(combatant.character, Global.read_config('ffg', 'wound_characteristic'))
        brawn + armor_soak
      else
        (combatant.npc_soak || 0) + armor_soak
      end
    end

    def self.defense_for(combatant)
      armor_config = Ffg.find_armor_config(combatant.armor) || {}
      (armor_config['defense'] || 0).to_i
    end

    # Builds the roll string for an attack: the attacker's dice, difficulty for the range,
    # extra difficulty for shooting past the weapon's range, and setback for the target's
    # defense.
    #
    # PCs roll the weapon's skill by name so their characteristic and skill ratings are
    # looked up off the sheet.  NPCs have no sheet, so their skill rating becomes that many
    # ability dice directly - passing a skill name for them would send a nil character into
    # find_skill_dice.
    def self.attack_roll_string(attacker, defender, weapon_config)
      difficulty = Ffg.range_difficulty(defender.range_band) + Ffg.range_penalty(defender, weapon_config)
      defense = Ffg.defense_for(defender)

      roll_str = if attacker.is_pc?
        weapon_config['skill'].to_s
      else
        "#{[ attacker.npc_skill || 1, 1 ].max}A"
      end

      roll_str = "#{roll_str}+#{difficulty}D" if difficulty > 0
      roll_str = "#{roll_str}+#{defense}S" if defense > 0
      roll_str
    end

    # Resolves one attack.  Returns a hash describing what happened; whether the damage is
    # actually written depends on Ffg.auto_apply?.
    def self.resolve_attack(combat, attacker, defender, weapon_name = nil)
      weapon_config = Ffg.find_weapon_config(weapon_name || attacker.weapon) || Ffg.default_weapon_config
      return { error: t('ffg.no_such_weapon') } if !weapon_config

      roll_str = Ffg.attack_roll_string(attacker, defender, weapon_config)

      roll = if attacker.is_pc?
        Ffg.make_roll(attacker.character, roll_str, combat.scene_id)
      else
        Ffg.make_npc_roll(combat, roll_str)
      end

      return { error: t('ffg.invalid_ability_name') } if !roll

      result = {
        attacker: attacker.display_name,
        defender: defender.display_name,
        weapon: weapon_config['name'],
        roll: roll,
        roll_string: roll_str,
        hit: roll.successful,
        damage: 0,
        soak: Ffg.soak_for(defender),
        wounds_dealt: 0,
        crit_cost: (weapon_config['crit'] || 3).to_i,
        crit_available: false,
        applied: false
      }

      return result if !roll.successful

      successes = (roll.dice || []).select { |d| d == 'S' || d == 'TRI' }.count
      failures = (roll.dice || []).select { |d| d == 'F' || d == 'DES' }.count
      net_successes = successes - failures

      base_damage = (weapon_config['damage'] || 0).to_i
      base_damage += Ffg.weapon_characteristic_damage(attacker, weapon_config)

      result[:damage] = base_damage + net_successes
      result[:wounds_dealt] = [ result[:damage] - result[:soak], 0 ].max
      result[:crit_available] = result[:wounds_dealt] > 0 && roll.available_advantage >= result[:crit_cost]

      if Ffg.auto_apply? && result[:wounds_dealt] > 0
        Ffg.apply_wounds(defender, result[:wounds_dealt])
        result[:applied] = true
      end

      result[:incapacitated] = defender.incapacitated?
      result
    end

    def self.weapon_characteristic_damage(attacker, weapon_config)
      charac = weapon_config['characteristic']
      return 0 if charac.blank?
      return 0 if !attacker.is_pc?
      Ffg.characteristic_rating(attacker.character, charac)
    end

    # NPCs have no character record to hang a roll off, so theirs are tagged with the
    # combat instead and cleaned up when it ends.  They're still real FfgRolls so a GM can
    # spend their advantage and threat.
    def self.make_npc_roll(combat, roll_str)
      dice = Ffg.roll_ability(nil, roll_str)
      return nil if !dice

      results = Ffg.determine_outcome(dice)

      FfgRoll.create(
        combat_id: combat.id.to_s,
        scene_id: combat.scene_id,
        roll_string: roll_str,
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
        created_at: Time.now.to_i
      )
    end

    # Wounds land on the sheet for PCs and on the combatant for NPCs, but both clamp the
    # same way.
    def self.apply_wounds(combatant, amount)
      if combatant.is_pc?
        Ffg.change_wounds(combatant.character, amount)
      else
        max = combatant.npc_wound_threshold || 0
        current = combatant.npc_wounds || 0
        combatant.update(npc_wounds: [ [ current + amount, 0 ].max, max ].min)
        combatant.npc_wounds
      end
    end

    # Builds the room message for an attack result.  Kept here so the command and the web
    # handler say the same thing.
    def self.attack_message(result)
      roll = result[:roll]
      lines = []

      if !result[:hit]
        lines << t('ffg.attack_missed',
          :attacker => result[:attacker],
          :defender => result[:defender],
          :weapon => result[:weapon],
          :dice => roll.print_dice,
          :id => roll.id)
        return lines.join("%r")
      end

      if result[:wounds_dealt] < 1
        lines << t('ffg.attack_soaked',
          :attacker => result[:attacker],
          :defender => result[:defender],
          :weapon => result[:weapon],
          :damage => result[:damage],
          :soak => result[:soak],
          :dice => roll.print_dice,
          :id => roll.id)
      else
        key = result[:applied] ? 'ffg.attack_damage_applied' : 'ffg.attack_damage_suggested'
        lines << t(key,
          :attacker => result[:attacker],
          :defender => result[:defender],
          :weapon => result[:weapon],
          :damage => result[:damage],
          :soak => result[:soak],
          :wounds => result[:wounds_dealt],
          :dice => roll.print_dice,
          :id => roll.id)
      end

      if result[:crit_available]
        lines << t('ffg.crit_available',
          :cost => result[:crit_cost],
          :id => roll.id,
          :defender => result[:defender])
      end

      if result[:incapacitated]
        lines << t('ffg.combatant_incapacitated', :name => result[:defender])
      end

      lines.join("%r")
    end

    # ------------------------------------------------------------
    # Web data
    # ------------------------------------------------------------

    def self.build_web_combat_data(combat, viewer)
      order = combat.initiative_order
      active = combat.active_combatant

      {
        id: combat.id,
        round: combat.round || 0,
        started: (combat.round || 0) > 0,
        active: active ? active.display_name : nil,
        automation: Ffg.auto_apply? ? 'auto' : 'suggest',
        weapons: (Global.read_config('ffg', 'weapons') || []).map { |w| w['name'] },
        range_bands: Ffg.range_bands,
        viewer_in_combat: !Ffg.find_combatant(combat, viewer.name).nil?,
        combatants: order.map { |c| Ffg.build_web_combatant_data(c, active) }
      }
    end

    def self.build_web_combatant_data(combatant, active)
      wound_max = combatant.wound_threshold
      strain_max = combatant.strain_threshold
      tier_config = Ffg.adversary_tier_config(combatant.tier)

      {
        name: combatant.display_name,
        is_pc: combatant.is_pc?,
        tier: tier_config['name'] || combatant.tier,
        weapon: combatant.weapon,
        armor: combatant.armor,
        range_band: combatant.range_band,
        soak: Ffg.soak_for(combatant),
        minion_count: combatant.minion_count || 1,
        crit_count: combatant.crit_count || 0,
        is_group: (combatant.minion_count || 1) > 1,
        has_crits: (combatant.crit_count || 0) > 0,
        incapacitated: combatant.incapacitated?,
        is_active: active && active.display_name == combatant.display_name,
        wounds: {
          current: combatant.wounds,
          max: wound_max,
          percent: wound_max > 0 ? ((combatant.wounds.to_f / wound_max) * 100).round : 0
        },
        strain: {
          current: combatant.strain,
          max: strain_max,
          percent: strain_max > 0 ? ((combatant.strain.to_f / strain_max) * 100).round : 0,
          tracked: combatant.is_pc? || !!tier_config['uses_strain']
        }
      }
    end

    # ------------------------------------------------------------
    # Critical injuries
    # ------------------------------------------------------------

    def self.find_critical_injury(total)
      injuries = Global.read_config('ffg', 'critical_injuries') || []
      injuries.select { |i| total >= (i['min'] || 0).to_i && total <= (i['max'] || 0).to_i }.first
    end

    # A critical rolls d100 and adds 10 for every critical the target is already carrying.
    def self.roll_critical(combatant)
      severity = (combatant.crit_count || 0) * 10
      roll = rand(100) + 1
      total = roll + severity

      injury = Ffg.find_critical_injury(total)
      combatant.update(crit_count: (combatant.crit_count || 0) + 1)

      {
        roll: roll,
        severity: severity,
        total: total,
        name: injury ? injury['name'] : t('ffg.unknown_critical'),
        effect: injury ? injury['effect'] : ""
      }
    end

    # Spends the advantage a critical costs off the attack roll, then rolls the injury.
    def self.trigger_critical(roll, combatant, cost)
      return [ nil, t('ffg.not_enough_advantage_for_crit', :cost => cost) ] if roll.available_advantage < cost

      Ffg.record_spend(roll, 'advantage', cost)
      [ Ffg.roll_critical(combatant), nil ]
    end

  end
end
