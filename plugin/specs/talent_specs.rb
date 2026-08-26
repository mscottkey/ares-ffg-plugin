module AresMUSH
  module Ffg
    describe Ffg do 
      
      before do
        stub_translate_for_testing
      end      
      
      describe :talent_tree_balanced_for_add do
        before do
          @char = double
        end

        it "should always return balanced for tier 1" do
          balanced = Ffg.talent_tree_balanced_for_add(@char, 1)
          expect(balanced).to eq true
        end

        it "should succeed if room at new tier" do
          talents = [ FfgTalent.new(tier: 1, rating: 1), FfgTalent.new(tier: 1, rating: 1) ]
          allow(@char).to receive(:ffg_talents) { talents }
          balanced = Ffg.talent_tree_balanced_for_add(@char, 2)
          expect(balanced).to eq true
        end

        it "should fail if no room at new tier" do
          talents = [ FfgTalent.new(tier: 1, rating: 1) ]
          allow(@char).to receive(:ffg_talents) { talents }
          balanced = Ffg.talent_tree_balanced_for_add(@char, 2)
          expect(balanced).to eq false
        end
        
        it "should fail if not more than one slot open" do
          talents = [ FfgTalent.new(tier: 1, rating: 1), FfgTalent.new(tier: 1, rating: 1), FfgTalent.new(tier: 2, rating: 1) ]
          allow(@char).to receive(:ffg_talents) { talents }
          balanced = Ffg.talent_tree_balanced_for_add(@char, 2)
          expect(balanced).to eq false
        end
        
        it "should account for ratings in tier filling up" do
          talents = [ FfgTalent.new(tier: 2, rating: 1), FfgTalent.new(tier: 1, rating: 3, ranked: true), FfgTalent.new(tier: 1, rating: 1) ]
          allow(@char).to receive(:ffg_talents) { talents }
          balanced = Ffg.talent_tree_balanced_for_add(@char, 2)
          expect(balanced).to eq false
        end
        
        it "should account for ratings in tier providing foundation" do
          talents = [ FfgTalent.new(tier: 1, rating: 1), FfgTalent.new(tier: 1, rating: 1), FfgTalent.new(tier: 1, rating: 1), FfgTalent.new(tier: 1, rating: 2, ranked: true) ]
          allow(@char).to receive(:ffg_talents) { talents }
          balanced = Ffg.talent_tree_balanced_for_add(@char, 2)
          expect(balanced).to eq true
        end
        
      end
      
      describe :talent_tree_balanced_for_remove do
        before do
          @char = double
        end

        it "should always return balanced for tier 5" do
          allow(@char).to receive(:ffg_talents) { [] }
          balanced = Ffg.talent_tree_balanced_for_remove(@char, 5)
          expect(balanced).to eq true
        end

        it "should succeed if extra talents" do
          talents = [ FfgTalent.new(tier: 2, rating: 1), FfgTalent.new(tier: 2, rating: 1), FfgTalent.new(tier: 2, rating: 1), FfgTalent.new(tier: 3, rating: 1) ]
          allow(@char).to receive(:ffg_talents) { talents }
          balanced = Ffg.talent_tree_balanced_for_remove(@char, 2)
          expect(balanced).to eq true
        end

        it "should succeed if no talents at next level" do
          talents = [ FfgTalent.new(tier: 2), FfgTalent.new(tier: 1, rating: 1), FfgTalent.new(tier: 1, rating: 1) ]
          pp talents
          allow(@char).to receive(:ffg_talents) { talents }
          balanced = Ffg.talent_tree_balanced_for_remove(@char, 2)
          expect(balanced).to eq true
        end

        it "should fail if removing talent would make it short" do
          talents = [ FfgTalent.new(tier: 2, rating: 1), FfgTalent.new(tier: 2, rating: 1), FfgTalent.new(tier: 3, rating: 1) ]
          allow(@char).to receive(:ffg_talents) { talents }
          balanced = Ffg.talent_tree_balanced_for_remove(@char, 2)
          expect(balanced).to eq false
        end
        
        it "should account for ratings in tier filling up" do
          talents = [ FfgTalent.new(tier: 2, rating: 1), FfgTalent.new(tier: 1, rating: 3, ranked: true), FfgTalent.new(tier: 1, rating: 1), FfgTalent.new(tier: 1, rating: 2), FfgTalent.new(tier: 3, rating: 1) ]
          allow(@char).to receive(:ffg_talents) { talents }
          balanced = Ffg.talent_tree_balanced_for_remove(@char, 2)
          expect(balanced).to eq false
        end
        
        it "should account for ratings in tier providing foundation xxxx" do
          talents = [ FfgTalent.new(tier: 1, rating: 2, ranked: true), FfgTalent.new(tier: 2, rating: 1), FfgTalent.new(tier: 2, rating: 1), FfgTalent.new(tier: 3, rating: 1) ]
          allow(@char).to receive(:ffg_talents) { talents }
          balanced = Ffg.talent_tree_balanced_for_remove(@char, 2)
          expect(balanced).to eq true
        end

      end

      describe :talent_tier_counts do

        it "should count an unranked talent only at its own tier" do
          counts = Ffg.talent_tier_counts([ FfgTalent.new(tier: 3, rating: 1) ])
          expect(counts[1]).to eq 0
          expect(counts[3]).to eq 1
          expect(counts[4]).to eq 0
        end

        it "should count a ranked talent at every tier it reaches" do
          counts = Ffg.talent_tier_counts([ FfgTalent.new(tier: 1, rating: 3, ranked: true) ])
          expect(counts[1]).to eq 1
          expect(counts[2]).to eq 1
          expect(counts[3]).to eq 1
          expect(counts[4]).to eq 0
        end

        it "should return a count for every tier when there are no talents" do
          counts = Ffg.talent_tier_counts([])
          expect(counts.values).to eq [ 0, 0, 0, 0, 0 ]
        end
      end

      describe :talent_tree_balanced? do

        it "should be balanced with no talents" do
          expect(Ffg.talent_tree_balanced?([])).to eq true
        end

        it "should be balanced with only tier 1 talents" do
          talents = [ FfgTalent.new(tier: 1, rating: 1), FfgTalent.new(tier: 1, rating: 1) ]
          expect(Ffg.talent_tree_balanced?(talents)).to eq true
        end

        # The Grit(2)/Dodge(1) example from the README.
        it "should be balanced when each tier is smaller than the one below it" do
          talents = [ FfgTalent.new(tier: 1, rating: 2, ranked: true), FfgTalent.new(tier: 1, rating: 1) ]
          expect(Ffg.talent_tree_balanced?(talents)).to eq true
        end

        # Bob's Grit(3)/Dodge(3)/Reaction(2) tree from the README.
        it "should be unbalanced when a tier matches the one below it" do
          talents = [ FfgTalent.new(tier: 1, rating: 3, ranked: true),
                      FfgTalent.new(tier: 1, rating: 3, ranked: true),
                      FfgTalent.new(tier: 1, rating: 2, ranked: true) ]
          expect(Ffg.talent_tree_balanced?(talents)).to eq false
        end

        # ...and the extra tier 1 talent the README says fixes it.
        it "should be balanced once the foundation is widened" do
          talents = [ FfgTalent.new(tier: 1, rating: 3, ranked: true),
                      FfgTalent.new(tier: 1, rating: 3, ranked: true),
                      FfgTalent.new(tier: 1, rating: 2, ranked: true),
                      FfgTalent.new(tier: 1, rating: 1) ]
          expect(Ffg.talent_tree_balanced?(talents)).to eq true
        end

        it "should be unbalanced with a high tier talent and no foundation" do
          talents = [ FfgTalent.new(tier: 2, rating: 1) ]
          expect(Ffg.talent_tree_balanced?(talents)).to eq false
        end
      end
    end
  end
end

        
