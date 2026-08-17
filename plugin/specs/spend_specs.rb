module AresMUSH
  module Ffg
    describe Ffg do

      before do
        stub_translate_for_testing
      end

      describe :symbol_remaining do
        before do
          @roll = FfgRoll.new(net_advantage: 3, net_threat: 0, triumph: true, despair: false,
                              spent_advantage: 1, spent_threat: 0, spent_triumph: 0, spent_despair: 0)
        end

        it "should subtract what has already been spent" do
          expect(Ffg.symbol_remaining(@roll, 'advantage')).to eq 2
        end

        it "should report a triumph as one symbol" do
          expect(Ffg.symbol_remaining(@roll, 'triumph')).to eq 1
        end

        it "should report nothing for a symbol the roll didn't generate" do
          expect(Ffg.symbol_remaining(@roll, 'despair')).to eq 0
        end

        it "should report nothing for an unknown symbol" do
          expect(Ffg.symbol_remaining(@roll, 'bogus')).to eq 0
        end
      end

      describe :available_spends do
        before do
          allow(Global).to receive(:read_config).with('ffg', 'spends') do
            {
              'advantage' => [
                { 'name' => 'Recover Strain', 'cost' => 1, 'effect' => 'recover_strain', 'target' => 'self' },
                { 'name' => 'Add A Fact', 'cost' => 2, 'effect' => 'narrative', 'target' => 'none' }
              ],
              'threat' => [
                { 'name' => 'Suffer Strain', 'cost' => 1, 'effect' => 'suffer_strain', 'target' => 'self' }
              ]
            }
          end
        end

        it "should offer nothing when the roll has no symbols left" do
          roll = FfgRoll.new(net_advantage: 0, net_threat: 0, spent_advantage: 0, spent_threat: 0)
          expect(Ffg.available_spends(roll)).to be_empty
        end

        it "should only offer what the roll can afford" do
          roll = FfgRoll.new(net_advantage: 1, net_threat: 0, spent_advantage: 0, spent_threat: 0)
          names = Ffg.available_spends(roll).map { |s| s['name'] }
          expect(names).to eq [ 'Recover Strain' ]
        end

        it "should offer the pricier spend once the roll can afford it" do
          roll = FfgRoll.new(net_advantage: 2, net_threat: 0, spent_advantage: 0, spent_threat: 0)
          names = Ffg.available_spends(roll).map { |s| s['name'] }
          expect(names).to eq [ 'Recover Strain', 'Add A Fact' ]
        end

        it "should offer spends from every symbol the roll has" do
          roll = FfgRoll.new(net_advantage: 1, net_threat: 1, spent_advantage: 0, spent_threat: 0)
          spends = Ffg.available_spends(roll)
          expect(spends.map { |s| s['symbol'] }).to eq [ 'advantage', 'threat' ]
        end

        it "should stop offering a spend once the symbols are used up" do
          roll = FfgRoll.new(net_advantage: 1, net_threat: 0, spent_advantage: 1, spent_threat: 0)
          expect(Ffg.available_spends(roll)).to be_empty
        end
      end

      describe :auto_apply? do
        it "should default to suggest" do
          allow(Global).to receive(:read_config).with('ffg', 'automation') { nil }
          expect(Ffg.auto_apply?).to eq false
        end

        it "should be false when set to suggest" do
          allow(Global).to receive(:read_config).with('ffg', 'automation') { 'suggest' }
          expect(Ffg.auto_apply?).to eq false
        end

        it "should be true when set to auto" do
          allow(Global).to receive(:read_config).with('ffg', 'automation') { 'auto' }
          expect(Ffg.auto_apply?).to eq true
        end
      end

      describe :change_strain do
        before do
          @char = double
          allow(@char).to receive(:ffg_strain_threshold) { 10 }
        end

        it "should add strain" do
          allow(@char).to receive(:ffg_strain) { 2 }
          expect(@char).to receive(:update).with(ffg_strain: 5)
          expect(Ffg.change_strain(@char, 3)).to eq 5
        end

        it "should recover strain" do
          allow(@char).to receive(:ffg_strain) { 5 }
          expect(@char).to receive(:update).with(ffg_strain: 3)
          expect(Ffg.change_strain(@char, -2)).to eq 3
        end

        it "should not go below zero" do
          allow(@char).to receive(:ffg_strain) { 1 }
          expect(@char).to receive(:update).with(ffg_strain: 0)
          expect(Ffg.change_strain(@char, -5)).to eq 0
        end

        it "should not go above the threshold" do
          allow(@char).to receive(:ffg_strain) { 8 }
          expect(@char).to receive(:update).with(ffg_strain: 10)
          expect(Ffg.change_strain(@char, 5)).to eq 10
        end
      end

      describe :incapacitated? do
        before do
          @char = double
          allow(@char).to receive(:ffg_wound_threshold) { 12 }
          allow(@char).to receive(:ffg_strain_threshold) { 10 }
        end

        it "should not be incapacitated below both thresholds" do
          allow(@char).to receive(:ffg_wounds) { 5 }
          allow(@char).to receive(:ffg_strain) { 5 }
          expect(Ffg.incapacitated?(@char)).to eq false
        end

        it "should be incapacitated at the wound threshold" do
          allow(@char).to receive(:ffg_wounds) { 12 }
          allow(@char).to receive(:ffg_strain) { 0 }
          expect(Ffg.incapacitated?(@char)).to eq true
        end

        it "should be incapacitated at the strain threshold" do
          allow(@char).to receive(:ffg_wounds) { 0 }
          allow(@char).to receive(:ffg_strain) { 10 }
          expect(Ffg.incapacitated?(@char)).to eq true
        end
      end

    end
  end
end
