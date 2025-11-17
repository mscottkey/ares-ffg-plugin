module AresMUSH
  module Jobs
    # Gets custom fields for use in the jobs menu
    #
    # @param [Job] job - The job being requested.
    # @param [Character] viewer - The character viewing the job. 
    #
    # @return [Hash] - A hash containing custom fields and values. 
    #    Ansi or markdown text strings must be formatted for display.
    #    Return an empty hash if you don't need data
    # @example
    #    return { abilities: YourCustomPlugin.build_abilities_list }
    def self.custom_job_menu_fields(char, viewer)
      return {char_abilities: Ffg.web_abilities(viewer),
              fate_points: (viewer.fate_points > 0),
              char_points: (viewer.char_points > 0),
              wound_levels: viewer.is_admin? ? Ffg.wound_levels.map{ |a| a['name'] } : nil,
              natural_heal: Ffg.get_natural_difficulty(viewer.wound_level) != nil }
    end    
  end
end