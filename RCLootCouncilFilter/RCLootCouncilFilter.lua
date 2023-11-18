-- RCLootCouncilFilter.lua
-- November 2022

local addon, ns = ...
local LibDialog = LibStub("LibDialog-1.0")
RCLootCouncilFilter = LibStub("AceAddon-3.0"):NewAddon( "RCLootCouncilFilter", "AceEvent-3.0")
RCLootCouncilFilter.Version = GetAddOnMetadata( "RCLootCouncilFilter", "Version" )
RCLootCouncilFilter.Flavor = GetAddOnMetadata( "RCLootCouncilFilter", "X-Flavor" ) or "Retail"

local buildStr, _, _, buildNum = GetBuildInfo()
RCLootCouncilFilter.CurrentBuild = buildNum
if RCLootCouncilFilter.Version == ( "@" .. "project-version" .. "@" ) then
    RCLootCouncilFilter.Version = (("Dev-%s (%s)"):format(buildStr, date( "%Y%m%d" ) ))
end

RCLootCouncilFilter.IsDragonflight = function()
    return buildNum >= 100000
end

-- Skip execution if RCLootCouncil is missing. Can extend with version checks if needed.
if not RCLootCouncil then
    print("RCLootCouncilFilter: Unable to find RCLootCouncil addon installed.")
    return
end

if not RCLootCouncilFilter.IsDragonflight() then
    print("RCLootCouncilFilter only supports Dragonflight.")
    return
end

---Prints during debug execution.
---@param formatString string
local function DebugPrint(formatString, ...)
    --[==[@debug@
    local arg = {...}

    print('RCLootCouncilFilter: ' .. string.format(formatString, unpack(arg)))
    --@end-debug@]==]
end

--[[-----------------------------------------------------------------------------
RCLootCouncil Integration
-------------------------------------------------------------------------------]]

--- Updates RCLootCouncil's enabled state.
---@param enabled boolean
local function UpdateRCLootCouncilEnabled(enabled)
    if RCLootCouncil.enabled == enabled then return end
    RCLootCouncil.enabled = enabled
    -- Check if this is disabled while still master looter.
    if not RCLootCouncil.enabled and RCLootCouncil.isMasterLooter then
        RCLootCouncil.isMasterLooter = false
        RCLootCouncil.masterLooter = nil
        RCLootCouncil:GetActiveModule("masterlooter"):Disable()
    else
        RCLootCouncil:NewMLCheck()
    end
end

--[[-----------------------------------------------------------------------------
RCLootCouncilFilter Instance Data
-------------------------------------------------------------------------------]]

RCLootCouncilFilter.isInInstance = false
RCLootCouncilFilter.wereSettingsUpdated = false

--[[-----------------------------------------------------------------------------
Confirmation Dialog
-------------------------------------------------------------------------------]]

local dialogName = "RCLOOTCOUNCILFILTER_CONFIRMATION"

StaticPopupDialogs[dialogName] = {
    text = "Enable RCLootCouncil for this instance?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        UpdateRCLootCouncilEnabled(true)
    end,
    OnCancel = function (_,_, reason)
        UpdateRCLootCouncilEnabled(false)
    end,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    sound = SOUNDKIT.RAID_WARNING,
}

--[[-----------------------------------------------------------------------------
Private Helpers
-------------------------------------------------------------------------------]]

--- Determine's if the raid group represents the player's progression raid group.
---@return boolean isGuildGroup True if the player is in a group lead by their guildmates.
local function IsGuildGroup()
    local playerGuild = GetGuildInfo("player")
    local playerName = UnitName("player")

    for raidIndex = 1,MAX_RAID_MEMBERS do
        local name, rank = GetRaidRosterInfo(raidIndex)
        local sameServer = name and not name:find("-")
        -- If off-realm player exists, is not the current player, and is lead.
        if sameServer and playerName ~= name and rank == 2 then
            local guild = GetGuildInfo("raid" .. tostring(raidIndex))
            if guild and guild ~= playerGuild then
                -- If a raid leader is from another guild, then assume not guild group.
                return false
            end
        end
    end

    -- No non-guild leaders found, so assume guild group.
    return true
end

--[[-----------------------------------------------------------------------------
Hook Options Interface Eventing
-------------------------------------------------------------------------------]]

SettingsPanel:HookScript("OnShow", function()
    DebugPrint("Launching options.")
    RCLootCouncilFilter.wereSettingsUpdated = false
end)

SettingsPanel:HookScript("OnHide", function()
    DebugPrint("Options were closed, were updated: %s", tostring(RCLootCouncilFilter.wereSettingsUpdated))
    if RCLootCouncilFilter.wereSettingsUpdated then
        RCLootCouncilFilter.isInInstance = false  -- Cleared to try again.
        RCLootCouncilFilter:UpdateRCLootCouncil()
    end
end)

--[[-----------------------------------------------------------------------------
Options
-------------------------------------------------------------------------------]]

local raidDifficultyOptions = "raidDifficultyOptions"
local guildGroupOptions = "guildGroupOptions"
---@alias difficulties
---| '"normal"'
---| '"heroic"'
---| '"mythic"'
local DIFFICULTIES = {
    normal = "normal",
    heroic = "heroic",
    mythic = "mythic",
}
---@type table<integer, difficulties>
local difficultyIDToString = {
    [14] = DIFFICULTIES.normal,
    [15] = DIFFICULTIES.heroic,
    [16] = DIFFICULTIES.mythic,
}

--- Sets the default options if they're not set, otherwise does nothing.
function RCLootCouncilFilter:SetDefaultOpions()
    if self.db.profile.options then return end

    self.db.profile.options = {
        raidDifficultyOptions = {
            [DIFFICULTIES.normal] = false,
            [DIFFICULTIES.heroic] = false,
            [DIFFICULTIES.mythic] = true,
        },
        guildGroupOptions = {
            [DIFFICULTIES.normal] = true,
            [DIFFICULTIES.heroic] = true,
            [DIFFICULTIES.mythic] = true,
        },
    }
end

--- Gets the option value for the provided info.
---@param info any An option data structure.
---@return any value The value of the option currently stored in the db profile.
function RCLootCouncilFilter:GetOptionValue(info)
    local option = info[#info - 1]
    if option and option ~= raidDifficultyOptions and option ~= guildGroupOptions then
        return
    end

    local setting = info[#info]
    local value = self.db.profile.options[option][setting]
    DebugPrint("Get %s[%s] = %s", option, setting, tostring(value))
    return value
end

--- Gets the option value for the provided info.
---@param info any An option data structure.
---@return any value The value of the option currently stored in the db profile.
function RCLootCouncilFilter:SetOptionValue(info, value)
    local option = info[#info - 1]
    if option and option ~= raidDifficultyOptions and option ~= guildGroupOptions then
        return
    end

    local setting = info[#info]
    if self.db.profile.options[option][setting] ~= value then
        self.db.profile.options[option][setting] = value
        RCLootCouncilFilter.wereSettingsUpdated = true
    end
    DebugPrint("Set %s[%s] = %s", option, setting, tostring(value))
end

--- Gets the options table.
local function getOptions()
    local options = {
        name = "RCLootCouncilFilter",
        type = "group",
        handler = RCLootCouncilFilter,
        set = "SetOptionValue",
        get = "GetOptionValue",
        args = {
            raidDifficultyOptions = {
                order = 1,
                name = "Prompt Raid Difficulty",
                type = "group",
                inline = true,
                args = {
                    desc1 = {
                        order = 1,
                        name = "Display a confirmation dialog to enable RCLootCouncil at the start of raid instances for any checked difficulties.\n\nUnchecked boxes will auto-disable RCLootCouncil.",
                        type = "description",
                    },
                    normal = {
                        order = 2,
                        name = "Normal",
                        desc = "Enable prompting in Normal raids.",
                        type = "toggle",
                    },
                    heroic = {
                        order = 3,
                        name = "Heroic",
                        desc = "Enable prompting in Heroic raids.",
                        type = "toggle",
                    },
                    mythic = {
                        order = 4,
                        name = "Mythic",
                        desc = "Enable prompting in Mythic raids.",
                        type = "toggle",
                    },
                },
            },
            guildGroupOptions = {
                order = 2,
                name = "Guild Group Raid Difficulty",
                type = "group",
                inline = true,
                args = {
                    desc1 = {
                        order = 1,
                        name = "Automatically enable RCLootCouncil for any raid instances lead by your guild and matching the desired raid difficulty.\n\nUnchecked boxes will fall-back to the above prompt settings.",
                        type = "description",
                    },
                    normal = {
                        order = 2,
                        name = "Normal",
                        desc = "Enable RCLootCouncil in Guild-Led Normal raids.",
                        type = "toggle",
                    },
                    heroic = {
                        order = 3,
                        name = "Heroic",
                        desc = "Enable RCLootCouncil in Guild-Led Heroic raids.",
                        type = "toggle",
                    },
                    mythic = {
                        order = 4,
                        name = "Mythic",
                        desc = "Enable RCLootCouncil in Guild-Led Mythic raids.",
                        type = "toggle",
                    },
                },
            },
        },
    }
    return options
end

--[[-----------------------------------------------------------------------------
AceAddon
-------------------------------------------------------------------------------]]

function RCLootCouncilFilter:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("RCLootCouncilFilterDB", defaults, true)
    local options = getOptions()

    LibStub("AceConfig-3.0"):RegisterOptionsTable("RCLootCouncilFilter", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("RCLootCouncilFilter")

    self:SetDefaultOpions()
end

function RCLootCouncilFilter:OnEnable()
    -- Use zone changed because PLAYER_ENTERING_WORLD is firing too early for sound.
    RCLootCouncilFilter:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateRCLootCouncil")
    -- Manually trigger the first check because someone may of reloaded in an instance.
    self:UpdateRCLootCouncil()
end

RCLootCouncilFilter.isInInstance = false
--- Processes the current options and player situation to determine if and how RCLootCouncil should be updated.
--- If this matches the difficulty and is a guild group, then RCLootCouncil is enabled without a prompt.
--- Else-If this mathces the diff
function RCLootCouncilFilter:UpdateRCLootCouncil()
    if not self.enabledState then
        return
    end
    local isInInstance, instanceType = IsInInstance()
    if not isInInstance or instanceType ~= "raid" then
        DebugPrint("Not Raid Instance")
        RCLootCouncilFilter.isInInstance = false
        StaticPopup_Hide(dialogName)  -- Hide incase it was lingering from previous entry.
        return
    end

    -- If already in an instance then nothing to do.
    if RCLootCouncilFilter.isInInstance then
        DebugPrint("Already in instance.")
        return
    end

    -- Determine the instance difficulty
    local _, _, difficultyID = GetInstanceInfo()
    if not difficultyID or not difficultyIDToString[difficultyID] then
        DebugPrint("Unknown DifficultyID: %s", tostring(difficultyID))
        return
    end
    local difficultyName = difficultyIDToString[difficultyID]
    DebugPrint("Difficulty found: %s(%d)", tostring(difficultyName), tostring(difficultyID))

    -- Mark in instance to avoid prompting or changing settings again.
    RCLootCouncilFilter.isInInstance = true

    -- If the player is group lead, then do nothing since RCLootCouncil will handle it.
    if UnitIsGroupLeader("player") then
        DebugPrint("Player is group leader.")
        return
     end

    local enabledForGuild = self.db.profile.options[guildGroupOptions][difficultyName]
    local shouldPrompt = self.db.profile.options[raidDifficultyOptions][difficultyName]

    -- This is a guild group, and auto-enable is set for the difficulty.
    if IsGuildGroup() and enabledForGuild then
        DebugPrint("IsGuildGroup (%s,%s)", tostring(enabledForGuild), tostring(shouldPrompt))
        UpdateRCLootCouncilEnabled(true)
    -- User should be prompted to enable RCLootCouncil.
    elseif shouldPrompt then
        DebugPrint("ShouldPrompt (%s,%s)", tostring(enabledForGuild), tostring(shouldPrompt))
        StaticPopup_Show(dialogName)
    -- For lower difficulties auto-disable RCLootCouncil to avoid losing loot by accident.
    else
        DebugPrint("DisablingRCLC (%s,%s)", tostring(enabledForGuild), tostring(shouldPrompt))
        UpdateRCLootCouncilEnabled(false)
    end
end
