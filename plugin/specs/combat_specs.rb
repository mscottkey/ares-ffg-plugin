module AresMUSH
  module Ffg
    describe Ffg do

      before do
        stub_translate_for_testing

        allow(Global).to receive(:read_config).with('ffg', 'range_bands') do
          [ 'Engaged', 'Short', 'Medium', 'Long', 'Extreme' ]
        end
        allow(Global).to receive(:read_config).with('ffg', 'range_difficulty') do
          { 'Engaged' => 1, 'Short' => 1, 'Medium' => 2, 'Long' => 3, 'Extreme' => 4 }
        end
      end

      describe :range_penalty do
        before do
          @combatant = double
        end

        def penalty_for(target_band, weapon_band)
          allow(@combatant).to receive(:range_band) { target_band }
          Ffg.range_penalty(@combatant, { 'range' => weapon_band })
        end

        it "should not penalize a target at the weapon's own range" do
          expect(penalty_for('Medium', 'Medium')).to eq 0
        end

        it "should not penalize a target closer than the weapon's range" do
          expect(penalty_for('Engaged', 'Medium')).to eq 0
        end

        it "should penalize one die per band beyond the weapon's range" do
          expect(penalty_for('Long', 'Medium')).to eq 1
          expect(penalty_for('Extreme', 'Medium')).to eq 2
        end

        it "should penalize a melee weapon reaching across the map" do
          expect(penalty_for('Extreme', 'Engaged')).to eq 4
        end

        it "should not penalize an unrecognized band rather than making the shot impossible" do
          expect(penalty_for('Nonsense', 'Engaged')).to eq 0
        end
      end

      describe :range_difficulty do
        it "should read the difficulty for a band" do
          expect(Ffg.range_difficulty('Long')).to eq 3
        end

        it "should match a band case-insensitively" do
          expect(Ffg.range_difficulty('medium')).to eq 2
        end

        it "should default to one die for an unknown band" do
          expect(Ffg.range_difficulty('Nonsense')).to eq 1
        end
      end

      describe :soak_for do
        before do
          allow(Global).to receive(:read_config).with('ffg', 'armor') do
            [ { 'name' => 'None', 'soak' => 0, 'defense' => 0 },
              { 'name' => 'Heavy', 'soak' => 2, 'defense' => 1 } ]
          end
          allow(Global).to receive(:read_config).with('ffg', 'wound_characteristic') { 'Brawn' }
          @combatant = double
        end

        it "should add Brawn and armor for a PC" do
          char = double
          allow(@combatant).to receive(:is_pc?) { true }
          allow(@combatant).to receive(:character) { char }
          allow(@combatant).to receive(:armor) { 'Heavy' }
          allow(Ffg).to receive(:characteristic_rating).with(char, 'Brawn') { 3 }

          expect(Ffg.soak_for(@combatant)).to eq 5
        end

        it "should add the NPC's own soak and armor" do
          allow(@combatant).to receive(:is_pc?) { false }
          allow(@combatant).to receive(:npc_soak) { 2 }
          allow(@combatant).to receive(:armor) { 'Heavy' }

          expect(Ffg.soak_for(@combatant)).to eq 4
        end

        it "should treat unknown armor as no armor" do
          allow(@combatant).to receive(:is_pc?) { false }
          allow(@combatant).to receive(:npc_soak) { 2 }
          allow(@combatant).to receive(:armor) { 'Nonsense' }

          expect(Ffg.soak_for(@combatant)).to eq 2
        end
      end

      describe :attack_roll_string do
        before do
          allow(Global).to receive(:read_config).with('ffg', 'armor') do
            [ { 'name' => 'None', 'soak' => 0, 'defense' => 0 },
              { 'name' => 'Heavy', 'soak' => 2, 'defense' => 1 } ]
          end
          @attacker = double
          @defender = double
        end

        def roll_string_for(defender_band, weapon_band, armor)
          allow(@attacker).to receive(:is_pc?) { true }
          allow(@defender).to receive(:range_band) { defender_band }
          allow(@defender).to receive(:armor) { armor }
          Ffg.attack_roll_string(@attacker, @defender,
            { 'skill' => 'Ranged', 'range' => weapon_band })
        end

        it "should add difficulty for the range" do
          expect(roll_string_for('Medium', 'Medium', 'None')).to eq 'Ranged+2D'
        end

        it "should add the range penalty on top of the range difficulty" do
          expect(roll_string_for('Long', 'Medium', 'None')).to eq 'Ranged+4D'
        end

        it "should add setback for the target's defense" do
          expect(roll_string_for('Medium', 'Medium', 'Heavy')).to eq 'Ranged+2D+1S'
        end

        # An NPC has no sheet, so naming a skill here would send a nil character into
        # find_skill_dice.  Their skill rating becomes ability dice instead.
        it "should roll raw ability dice for an NPC rather than naming a skill" do
          allow(@attacker).to receive(:is_pc?) { false }
          allow(@attacker).to receive(:npc_skill) { 3 }
          allow(@defender).to receive(:range_band) { 'Medium' }
          allow(@defender).to receive(:armor) { 'None' }

          roll_str = Ffg.attack_roll_string(@attacker, @defender,
            { 'skill' => 'Ranged', 'range' => 'Medium' })

          expect(roll_str).to eq '3A+2D'
        end

        it "should give an NPC with no skill rating at least one die" do
          allow(@attacker).to receive(:is_pc?) { false }
          allow(@attacker).to receive(:npc_skill) { 0 }
          allow(@defender).to receive(:range_band) { 'Engaged' }
          allow(@defender).to receive(:armor) { 'None' }

          roll_str = Ffg.attack_roll_string(@attacker, @defender,
            { 'skill' => 'Brawl', 'range' => 'Engaged' })

          expect(roll_str).to eq '1A+1D'
        end
      end

      describe :find_critical_injury do
        before do
          allow(Global).to receive(:read_config).with('ffg', 'critical_injuries') do
            [ { 'min' => 1, 'max' => 20, 'name' => 'Minor Nick', 'effect' => 'a' },
              { 'min' => 21, 'max' => 30, 'name' => 'Slowed Down', 'effect' => 'b' },
              { 'min' => 91, 'max' => 100, 'name' => 'Bowled Over', 'effect' => 'c' },
              { 'min' => 101, 'max' => 110, 'name' => 'Head Ringer', 'effect' => 'd' } ]
          end
        end

        it "should find the lowest entry" do
          expect(Ffg.find_critical_injury(1)['name']).to eq 'Minor Nick'
        end

        it "should respect the top of a band" do
          expect(Ffg.find_critical_injury(20)['name']).to eq 'Minor Nick'
        end

        it "should respect the bottom of the next band" do
          expect(Ffg.find_critical_injury(21)['name']).to eq 'Slowed Down'
        end

        it "should handle a plain d100 maximum" do
          expect(Ffg.find_critical_injury(100)['name']).to eq 'Bowled Over'
        end

        # Severity from existing crits pushes the total past 100.
        it "should handle totals above 100" do
          expect(Ffg.find_critical_injury(101)['name']).to eq 'Head Ringer'
        end

        it "should return nothing past the end of the table" do
          expect(Ffg.find_critical_injury(500)).to be_nil
        end
      end

      describe :tier_names do
        it "should list the configured tiers" do
          allow(Global).to receive(:read_config).with('ffg', 'adversary_tiers') do
            { 'minion' => {}, 'rival' => {}, 'nemesis' => {} }
          end
          expect(Ffg.tier_names).to eq [ 'minion', 'rival', 'nemesis' ]
        end

        it "should be empty when nothing is configured" do
          allow(Global).to receive(:read_config).with('ffg', 'adversary_tiers') { nil }
          expect(Ffg.tier_names).to eq []
        end
      end

      describe :weapon_characteristic_damage do
        before do
          @attacker = double
        end

        it "should add nothing for a weapon with no characteristic" do
          expect(Ffg.weapon_characteristic_damage(@attacker, { 'damage' => 6 })).to eq 0
        end

        it "should add the characteristic rating for a PC" do
          char = double
          allow(@attacker).to receive(:is_pc?) { true }
          allow(@attacker).to receive(:character) { char }
          allow(Ffg).to receive(:characteristic_rating).with(char, 'Brawn') { 3 }

          expect(Ffg.weapon_characteristic_damage(@attacker, { 'characteristic' => 'Brawn' })).to eq 3
        end

        it "should add nothing for an NPC, which has no characteristics" do
          allow(@attacker).to receive(:is_pc?) { false }
          expect(Ffg.weapon_characteristic_damage(@attacker, { 'characteristic' => 'Brawn' })).to eq 0
        end
      end

    end
  end
end
