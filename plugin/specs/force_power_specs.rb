module AresMUSH
  module Ffg
    describe Ffg do

      before do
        stub_translate_for_testing
      end

      describe :force_power_xp_cost do
        before do
          allow(Ffg).to receive(:find_force_power_config).with("Move") do
            {
              'name' => 'Move',
              'base_xp_cost' => 10,
              'upgrades' => [
                { 'name' => 'Range', 'xp_cost' => 5, 'max_rank' => 4 },
                { 'name' => 'Strength', 'xp_cost' => 10, 'max_rank' => 4 },
                { 'name' => 'Control (Hurl)', 'xp_cost' => 15, 'max_rank' => 1, 'prereq' => 'Strength' }
              ]
            }
          end
        end

        it "should cost 0 for an unknown power" do
          allow(Ffg).to receive(:find_force_power_config).with("Bogus") { nil }
          expect(Ffg.force_power_xp_cost("Bogus", [])).to eq 0
        end

        it "should cost the base cost with no upgrades" do
          expect(Ffg.force_power_xp_cost("Move", [])).to eq 10
        end

        it "should handle a nil upgrade list" do
          expect(Ffg.force_power_xp_cost("Move", nil)).to eq 10
        end

        it "should add the cost of each upgrade" do
          expect(Ffg.force_power_xp_cost("Move", [ 'Range', 'Strength' ])).to eq 25
        end

        it "should charge for each rank of a repeated upgrade" do
          expect(Ffg.force_power_xp_cost("Move", [ 'Range', 'Range', 'Range' ])).to eq 25
        end

        it "should ignore upgrades that aren't in the config" do
          expect(Ffg.force_power_xp_cost("Move", [ 'Range', 'Nonsense' ])).to eq 15
        end
      end

      describe :validate_force_power_upgrades do
        before do
          @config = {
            'name' => 'Move',
            'base_xp_cost' => 10,
            'upgrades' => [
              { 'name' => 'Range', 'xp_cost' => 5, 'max_rank' => 2 },
              { 'name' => 'Strength', 'xp_cost' => 10, 'max_rank' => 4 },
              { 'name' => 'Control (Hurl)', 'xp_cost' => 15, 'max_rank' => 1, 'prereq' => 'Strength' }
            ]
          }
          @errors = []
        end

        it "should accept a legal upgrade list" do
          result = Ffg.validate_force_power_upgrades(@config, [ 'Range', 'Strength' ], @errors)
          expect(result).to eq [ 'Range', 'Strength' ]
          expect(@errors).to be_empty
        end

        it "should drop unknown upgrades" do
          result = Ffg.validate_force_power_upgrades(@config, [ 'Range', 'Nonsense' ], @errors)
          expect(result).to eq [ 'Range' ]
          expect(@errors.count).to eq 1
        end

        it "should allow repeated upgrades up to max rank" do
          result = Ffg.validate_force_power_upgrades(@config, [ 'Range', 'Range' ], @errors)
          expect(result).to eq [ 'Range', 'Range' ]
          expect(@errors).to be_empty
        end

        it "should drop upgrades past max rank" do
          result = Ffg.validate_force_power_upgrades(@config, [ 'Range', 'Range', 'Range' ], @errors)
          expect(result).to eq [ 'Range', 'Range' ]
          expect(@errors.count).to eq 1
        end

        it "should drop an upgrade whose prereq is missing" do
          result = Ffg.validate_force_power_upgrades(@config, [ 'Control (Hurl)' ], @errors)
          expect(result).to eq []
          expect(@errors.count).to eq 1
        end

        it "should accept an upgrade whose prereq is present" do
          result = Ffg.validate_force_power_upgrades(@config, [ 'Strength', 'Control (Hurl)' ], @errors)
          expect(result).to eq [ 'Strength', 'Control (Hurl)' ]
          expect(@errors).to be_empty
        end

        it "should not care what order the prereq arrives in" do
          result = Ffg.validate_force_power_upgrades(@config, [ 'Control (Hurl)', 'Strength' ], @errors)
          expect(result).to eq [ 'Control (Hurl)', 'Strength' ]
          expect(@errors).to be_empty
        end

        it "should match upgrade names case-insensitively" do
          result = Ffg.validate_force_power_upgrades(@config, [ 'range' ], @errors)
          expect(result).to eq [ 'Range' ]
          expect(@errors).to be_empty
        end

        it "should handle an empty list" do
          expect(Ffg.validate_force_power_upgrades(@config, [], @errors)).to eq []
          expect(@errors).to be_empty
        end
      end

    end
  end
end
