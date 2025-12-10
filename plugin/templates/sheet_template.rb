module AresMUSH    
  module Ffg
    class SheetTemplate < ErbTemplateRenderer
      attr_accessor :char
  
      def initialize(char)
        @char = char
        super File.dirname(__FILE__) + "/sheet.erb"
      end
      
      def summary
        summ = "#{char.ffg_archetype}"
        if (char.ffg_career)
          summ << "/#{char.ffg_career}"
        end
        if (char.ffg_specializations && char.ffg_specializations.any?)
          summ << " (#{char.ffg_specializations.join(', ')})"
        end
        summ
      end
      
      def talents
        @char.ffg_talents.to_a.sort_by { |a| a.name }
          .each_with_index
            .map do |a, i| 
              linebreak = i % 2 == 0 ? "\n" : ""
              title = a.name
              rating = a.ranked ? " (#{a.rating})" : ''
              display = left("#{title}#{rating}", 36)
              "#{linebreak}#{display}"
            end
      end
  
      def characteristics
        format_two_per_line @char.ffg_characteristics
      end
      
      def skills
        format_two_per_line @char.ffg_skills
      end
      
      def strain
        format_bar(@char.ffg_strain, @char.ffg_strain_threshold)
      end
      
      def wounds
        format_bar(@char.ffg_wounds, @char.ffg_wound_threshold)
      end
      
      def format_bar(current, max)
        current = current || 0
        max = max || 10
        x = current.times.map { |i| 'X' }.join
        o = (max - current).times.map { |i| 'o' }.join
        "#{x}#{o} (#{current}/#{max})"
      end
      
      def format_two_per_line(list)
        list.to_a.sort_by { |a| a.name }
          .each_with_index
            .map do |a, i| 
              linebreak = i % 2 == 0 ? "\n" : ""
              title = left("#{ a.name }:", 15)
              rating = left(a.rating, 20)
              "#{linebreak}%xh#{title}%xn #{rating}"
        end
      end

      def to_h
        {
          show_sheet: true,
          summary: summary,
          archetype: char.ffg_archetype,
          career: char.ffg_career,
          specializations: char.ffg_specializations || [],
          characteristics: char.ffg_characteristics.sort_by { |c| c.name }.map { |c| {
            name: c.name,
            rating: c.rating
          }},
          skills: char.ffg_skills.sort_by { |s| s.name }.map { |s| {
            name: s.name,
            rating: s.rating
          }},
          talents: char.ffg_talents.sort_by { |t| [t.tier || 1, t.name] }.map { |t| {
            name: t.name,
            rank: t.ranked ? t.rating : nil,
            tier: t.tier,
            specialization: t.specialization
          }},
          force_powers: char.ffg_force_powers.sort_by { |p| p.name }.map { |p| {
            name: p.name,
            upgrades: p.upgrades || []
          }},
          wounds: {
            current: char.ffg_wounds || 0,
            max: char.ffg_wound_threshold || 0
          },
          strain: {
            current: char.ffg_strain || 0,
            max: char.ffg_strain_threshold || 0
          },
          xp: char.ffg_xp || 0,
          force_rating: char.ffg_force_rating || 0,
          story_points: char.ffg_story_points || 0
        }
      end
    end
  end
end