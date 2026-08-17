$:.unshift File.dirname(__FILE__)

# Load web request handlers
require 'web/ffg_web_hooks'
require 'web/reset_char_request_handler'
require 'web/get_roll_spends_request_handler'
require 'web/apply_roll_spend_request_handler'

module AresMUSH
     module Ffg

    def self.plugin_dir
      File.dirname(__FILE__)
    end

    def self.shortcuts
      Global.read_config("ffg", "shortcuts")
    end

    def self.get_cmd_handler(client, cmd, enactor)
      case cmd.root
      when "archetype"
        return ArchetypesCmd
      when "characteristic"
        if (cmd.switch_is?("set"))
          return CharacteristicSetCmd
        else
          return CharacteristicsCmd
        end
      when "skill"
        if (cmd.switch_is?("set"))
          return SkillSetCmd
        else
          return SkillsCmd
        end
      when "specialization"
        if (cmd.switch_is?("add"))
          return SpecAddCmd
        elsif (cmd.switch_is?("remove"))
          return SpecRemoveCmd
        else
          return SpecializationsCmd
        end
      when "talent"
        if (cmd.switch_is?("add"))
          return TalentAddCmd
        elsif (cmd.switch_is?("remove"))
          return TalentRemoveCmd
        else
          return TalentsCmd
        end
      when "power"
        if (cmd.switch_is?("add"))
          return ForcePowerAddCmd
        elsif (cmd.switch_is?("upgrade"))
          return ForcePowerUpgradeCmd
        else
          return ForcePowersCmd
        end
      when "force", "wounds", "strain", "woundthresh", "strainthresh"
        return StatSetCmd
      when "career"
        return CareersCmd
      when "reset"
        return ResetCmd
      when "sheet"
        return SheetCmd
      when "roll"
        if (cmd.args && cmd.args =~ / vs /)
          return RollOpposedCmd
        else
          return RollCmd
        end
      when "spend"
        return SpendCmd
      when "spends"
        return SpendsCmd
      when "xp"
        if (cmd.switch_is?("award"))
          return XpAwardCmd
        end
      when "story"
        if (cmd.switch_is?("award"))
          return StoryPointAwardCmd
        elsif (cmd.switch_is?("spend"))
          return StoryPointSpendCmd
        end
      end
      return nil
    end

    def self.get_event_handler(event_name)
      nil
    end

    def self.get_web_request_handler(request)
      case request.cmd
      when "getChargenInfo"
        return GetChargenInfoRequestHandler
      when "resetAbilities"
        return ResetAbilitiesRequestHandler
      when "getRollSpends"
        return GetRollSpendsRequestHandler
      when "applyRollSpend"
        return ApplyRollSpendRequestHandler
      end
      nil
    end
    
    def self.plugin_version
      "2.0"
    end

  end
end
