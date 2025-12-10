module AresMUSH
  module Scenes

    def self.custom_scene_data(viewer)
      # Return nil if you don't need any custom data.
      return { char_abilities: Ffg.web_abilities(viewer) }
    end
  end
end