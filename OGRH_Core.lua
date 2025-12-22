-- OG-ReadHelper Core Functionality
-- Author: Gnuzmas
-- Version: 1.0.0

OGRH_Read = OGRH_Read or {}

-- Get version from TOC file
OGRH_Read.VERSION = GetAddOnMetadata("OG-ReadHelper", "Version") or "Unknown"

-- Addon prefix for communication
OGRH_Read.ADDON_PREFIX = "OGReadHelper"

-- Initialize saved variables
function OGRH_Read.EnsureSV()
  if not OGRH_Read_SV then
    OGRH_Read_SV = {
      version = "1.0.0",
      windows = {},
      settings = {
        -- Add default settings here
      }
    }
  end
end

-- ========================================
-- MODULE SYSTEM
-- ========================================
OGRH_Read.Modules = OGRH_Read.Modules or {}
OGRH_Read.LoadedModules = OGRH_Read.LoadedModules or {}

-- Register a module (called by module files on load)
function OGRH_Read.RegisterModule(module)
  if not module or not module.id or not module.name then
    return
  end
  
  OGRH_Read.Modules[module.id] = module
end

-- Load modules for a specific encounter (from sync data)
function OGRH_Read.LoadModulesForEncounter(moduleIds)
  -- Unload all currently loaded modules first
  OGRH_Read.UnloadAllModules()
  
  if not moduleIds or table.getn(moduleIds) == 0 then
    return
  end
  
  -- Load each module in order
  for i, moduleId in ipairs(moduleIds) do
    local module = OGRH_Read.Modules[moduleId]
    if module and module.OnLoad then
      module:OnLoad()
      table.insert(OGRH_Read.LoadedModules, module)
    end
  end
end

-- Unload all currently loaded modules
function OGRH_Read.UnloadAllModules()
  for i, module in ipairs(OGRH_Read.LoadedModules) do
    if module.OnUnload then
      module:OnUnload()
    end
  end
  OGRH_Read.LoadedModules = {}
end

-- Clean up all modules (called on addon unload)
function OGRH_Read.CleanupModules()
  OGRH_Read.UnloadAllModules()
  for id, module in pairs(OGRH_Read.Modules) do
    if module.OnCleanup then
      module:OnCleanup()
    end
  end
end

-- Message output helper
function OGRH_Read.Msg(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00OG-ReadHelper:|r " .. msg)
end

-- ========================================
-- CONSUME HELPER WRAPPERS
-- ========================================
-- These functions make the Consume Helper module work with OGRH_Read namespace
function OGRH_Read.ShowConsumeHelper()
  if ConsumeHelper and ConsumeHelper.ShowSetup then
    ConsumeHelper.ShowSetup()
  end
end

function OGRH_Read.ShowManageConsumes()
  if ConsumeHelper and ConsumeHelper.ShowManageConsumes then
    ConsumeHelper.ShowManageConsumes()
  end
end

-- Initialize addon
local function OnLoad()
  OGRH_Read.EnsureSV() 
  OGRH_Read.Msg("Loaded v" .. OGRH_Read.VERSION)
end

-- Event frame
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")

eventFrame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == "OG-ReadHelper" then
    OnLoad()
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- Additional initialization if needed
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, message, distribution, sender = arg1, arg2, arg3, arg4
    
    -- Handle sync response from RaidHelper
    if prefix == "OGRH" and string.sub(message, 1, 25) == "READHELPER_SYNC_RESPONSE;" then
      local serialized = string.sub(message, 26)
      if OGRH_Read.HandleSyncResponse then
        OGRH_Read.HandleSyncResponse(serialized, sender)
      end
    -- Handle addon poll from RaidHelper
    elseif prefix == "OGRH" and message == "ADDON_POLL" then
      -- Don't respond to our own messages
      local playerName = UnitName("player")
      if sender == playerName then
        return
      end
      
      -- Respond with our version (no checksum for ReadHelper)
      local numRaid = GetNumRaidMembers()
      if numRaid > 0 then
        local response = "READHELPER_POLL_RESPONSE;" .. OGRH_Read.VERSION
        SendAddonMessage("OGRH", response, "RAID")
      end
    end
  end
end)

-- Utility function to create a styled window frame
function OGRH_Read.CreateStyledWindow(name, title, width, height)
  local frame = CreateFrame("Frame", name, UIParent)
  frame:SetWidth(width)
  frame:SetHeight(height)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("HIGH")
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
  })
  frame:SetBackdropColor(0, 0, 0, 0.9)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function() frame:StartMoving() end)
  frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
  
  -- Title
  local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleText:SetPoint("TOP", frame, "TOP", 0, -10)
  titleText:SetText(title)
  frame.title = titleText
  
  -- Close button
  local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  closeBtn:SetWidth(60)
  closeBtn:SetHeight(24)
  closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
  closeBtn:SetText("Close")
  closeBtn:SetScript("OnClick", function() frame:Hide() end)
  frame.closeBtn = closeBtn
  
  frame:Hide()
  return frame
end

-- Texture display helper
function OGRH_Read.CreateTextureDisplay(parent, width, height)
  local texture = parent:CreateTexture(nil, "ARTWORK")
  texture:SetWidth(width)
  texture:SetHeight(height)
  
  return texture
end

-- Image path helper for the images folder
function OGRH_Read.GetImagePath(filename)
  return "Interface\\AddOns\\OG-ReadHelper\\images\\" .. filename
end

-- Style a button with consistent teal backdrop and hover effects
function OGRH_Read.StyleButton(button)
  if not button then return end
  
  -- Hide the default textures
  local normalTexture = button:GetNormalTexture()
  if normalTexture then
    normalTexture:SetTexture(nil)
  end
  
  local highlightTexture = button:GetHighlightTexture()
  if highlightTexture then
    highlightTexture:SetTexture(nil)
  end
  
  local pushedTexture = button:GetPushedTexture()
  if pushedTexture then
    pushedTexture:SetTexture(nil)
  end
  
  -- Add custom backdrop with rounded corners and border
  button:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
  })
  
  -- Ensure button is fully opaque
  button:SetAlpha(1.0)
  
  -- Dark teal background color
  button:SetBackdropColor(0.25, 0.35, 0.35, 1)
  button:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  
  -- Add hover effect
  button:SetScript("OnEnter", function()
    this:SetBackdropColor(0.3, 0.45, 0.45, 1)
    this:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  end)
  
  button:SetScript("OnLeave", function()
    this:SetBackdropColor(0.25, 0.35, 0.35, 1)
    this:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
  end)
end

-- Show the RH menu using OGST menu system
function OGRH_Read.ShowMinimapMenu(sourceButton)
  if not OGRH_Read.Menu then
    -- Check if OGST is available
    if not OGST or not OGST.CreateStandardMenu then
      OGRH_Read.Msg("Error: OGST library not loaded!")
      return
    end
    
    -- Create OGST menu
    OGRH_Read.Menu = OGST.CreateStandardMenu({
      name = "OGRH_Read_MinimapMenu"
    })
    
    local menu = OGRH_Read.Menu
    
    -- Monitor Consumes toggle
    menu.monitorConsumesItem = menu:AddItem({
      text = "Monitor Consumes",
      onClick = function()
        OGRH_Read_SV.settings.monitorConsumes = not OGRH_Read_SV.settings.monitorConsumes
        OGRH_Read.UpdateMonitorConsumesText()
      end
    })
    
    -- Modules submenu
    menu:AddItem({
      text = "Modules",
      submenu = {
        {
          text = "Consume Helper",
          onClick = function()
            if OGRH_Read.ShowManageConsumes then
              OGRH_Read.ShowManageConsumes()
            else
              OGRH_Read.Msg("Consume Helper module not loaded.")
            end
          end
        }
      }
    })
    
    -- Finalize menu to set proper height
    menu:Finalize()
  end
  
  local menu = OGRH_Read.Menu
  
  -- Toggle menu visibility if already shown
  if menu:IsVisible() then
    menu:Hide()
    return
  end
  
  -- Update Monitor Consumes text before showing
  OGRH_Read.UpdateMonitorConsumesText()
  
  -- Show menu
  if sourceButton then
    menu:SetPoint("TOPLEFT", sourceButton, "BOTTOMLEFT", 0, -5)
  end
  menu:Show()
end

-- Update Monitor Consumes menu item text
function OGRH_Read.UpdateMonitorConsumesText()
  if OGRH_Read.Menu and OGRH_Read.Menu.monitorConsumesItem and OGRH_Read.Menu.monitorConsumesItem.fs then
    if OGRH_Read_SV and OGRH_Read_SV.settings and OGRH_Read_SV.settings.monitorConsumes then
      OGRH_Read.Menu.monitorConsumesItem.fs:SetText("|cff00ff00Monitor Consumes|r")
    else
      OGRH_Read.Menu.monitorConsumesItem.fs:SetText("Monitor Consumes")
    end
  end
end

-- ========================================
-- SYNC/COMMUNICATION
-- ========================================

-- Simple table deserialization (matches RaidHelper's format)
function OGRH_Read.Deserialize(str)
  if not str or str == "" then return nil end
  
  -- Basic deserialization - use loadstring
  local func = loadstring("return " .. str)
  if func then
    local success, result = pcall(func)
    if success then
      return result
    end
  end
  
  return nil
end

-- Handle sync response from RaidHelper
function OGRH_Read.HandleSyncResponse(serialized, sender)
  local data = OGRH_Read.Deserialize(serialized)
  
  if not data then
    OGRH_Read.Msg("Failed to parse sync data from " .. sender)
    return
  end
  
  -- Store sync data
  OGRH_Read.syncData = {
    encounter = data.encounter,
    announcement = data.announcement,
    consumes = data.consumes,
    modules = data.modules,
    sender = sender
  }
  
  -- Update encounter button text
  if OGRH_Read.MainUI and OGRH_Read.MainUI.encounterBtn then
    OGRH_Read.MainUI.encounterBtn:SetText(data.encounter or "Encounter")
  end
  
  -- Update consume display
  if OGRH_Read.UpdateConsumeDisplay then
    OGRH_Read.UpdateConsumeDisplay()
  end
  
  -- Load custom modules for this encounter
  if data.modules and OGRH_Read.LoadModulesForEncounter then
    OGRH_Read.LoadModulesForEncounter(data.modules)
  else
    -- No modules for this encounter, unload any currently loaded
    OGRH_Read.UnloadAllModules()
  end
end

-- Show announcement tooltip on encounter button hover
function OGRH_Read.ShowAnnouncementTooltip(anchorFrame)
  if not OGRH_Read.syncData or not OGRH_Read.syncData.announcement then
    return
  end
  
  local lines = OGRH_Read.syncData.announcement
  if not lines or table.getn(lines) == 0 then
    return
  end
  
  GameTooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")
  GameTooltip:ClearLines()
  
  for i = 1, table.getn(lines) do
    if lines[i] and lines[i] ~= "" then
      GameTooltip:AddLine(lines[i], 1, 1, 1, 1)
    end
  end
  
  GameTooltip:Show()
end

-- Create or update consume display
function OGRH_Read.UpdateConsumeDisplay()
  if not OGRH_Read.syncData or not OGRH_Read.syncData.consumes then
    -- Hide display if it exists
    if OGRH_Read_ConsumeDisplay then
      OGRH_Read_ConsumeDisplay:Hide()
    end
    return
  end
  
  local consumes = OGRH_Read.syncData.consumes
  if table.getn(consumes) == 0 then
    if OGRH_Read_ConsumeDisplay then
      OGRH_Read_ConsumeDisplay:Hide()
    end
    return
  end
  
  -- Create display frame if it doesn't exist
  if not OGRH_Read_ConsumeDisplay then
    local frame = CreateFrame("Frame", "OGRH_Read_ConsumeDisplay", UIParent)
    frame:SetWidth(180)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      edgeSize = 12,
      insets = {left = 4, right = 4, top = 4, bottom = 4}
    })
    frame:SetBackdropColor(0, 0, 0, 0.85)
    frame.rows = {}
  end
  
  local frame = OGRH_Read_ConsumeDisplay
  
  -- Clear existing rows
  for i = 1, table.getn(frame.rows) do
    frame.rows[i]:Hide()
  end
  
  -- Create/update rows for each consume
  local yOffset = -6
  local rowIndex = 1
  
  for i = 1, table.getn(consumes) do
    local consumeData = consumes[i]
    local row = frame.rows[i]
    
    if not row then
      -- Create new row
      row = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
      row:SetWidth(172)
      row:SetHeight(20)
      row:SetPoint("TOP", 0, yOffset)
      OGRH_Read.StyleButton(row)
      
      row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
      row.text:SetJustifyH("LEFT")
      
      frame.rows[i] = row
    end
    
    row:Show()
    row.consumeData = consumeData
    
    -- Set button text with trimming
    local itemName = consumeData.primaryName or "Unknown"
    -- Shorten consume name: "Greater" -> "G.", remove "Potion"
    itemName = string.gsub(itemName, "Greater ", "G. ")
    itemName = string.gsub(itemName, " Potion", "")
    
    -- Check if player has buff
    local hasBuff = false
    if consumeData.primarySpellId then
      hasBuff = OGRH_Read.HasConsumeBuff(consumeData.primarySpellId)
    end
    if not hasBuff and consumeData.secondarySpellId then
      hasBuff = OGRH_Read.HasConsumeBuff(consumeData.secondarySpellId)
    end
    
    -- Color text green if has buff, yellow if missing
    if hasBuff then
      row.text:SetText("|cff00ff00" .. itemName .. "|r")
    else
      row.text:SetText("|cffffd100" .. itemName .. "|r")
    end
    row:SetBackdropColor(0.25, 0.35, 0.35, 1)  -- Normal background
    
    -- Left-click to use consume
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function()
      OGRH_Read.UseConsume(this.consumeData)
    end)
    
    yOffset = yOffset - 22
    rowIndex = rowIndex + 1
  end
  
  -- Resize frame to match RaidHelper's calculation
  local newHeight = 6 + (rowIndex - 1) * 22 + 6
  frame:SetHeight(newHeight)
  
  -- Position frame function (called repeatedly to handle movement)
  local function PositionConsumeFrame()
    if not OGRH_Read.MainUI or not OGRH_Read.MainUI.frame then
      return
    end
    
    local screenHeight = UIParent:GetHeight()
    local mainBottom = OGRH_Read.MainUI.frame:GetBottom()
    local mainTop = OGRH_Read.MainUI.frame:GetTop()
    local frameHeight = frame:GetHeight()
    
    frame:ClearAllPoints()
    
    -- Try to dock below main UI
    if mainBottom and (mainBottom - frameHeight) > 0 then
      frame:SetPoint("TOP", OGRH_Read.MainUI.frame, "BOTTOM", 0, 0)
    -- Otherwise dock above main UI
    elseif mainTop and (mainTop + frameHeight) < screenHeight then
      frame:SetPoint("BOTTOM", OGRH_Read.MainUI.frame, "TOP", 0, 0)
    else
      -- Fallback to center if neither position works
      frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
  end
  
  PositionConsumeFrame()
  
  -- Setup OnUpdate to continuously reposition (checks every frame)
  if not frame.hasPositionUpdate then
    frame:SetScript("OnUpdate", function()
      PositionConsumeFrame()
    end)
    frame.hasPositionUpdate = true
  end
  
  frame:Show()
end



-- Check if player has consume buff
function OGRH_Read.HasConsumeBuff(spellId)
  if not spellId then return false end
  
  local i = 1
  while true do
    local texture, stacks, buffSpellId = UnitBuff("player", i)
    if not texture then break end
    
    if buffSpellId and buffSpellId == spellId then
      return true
    end
    
    i = i + 1
  end
  
  return false
end

-- Use consume from inventory
function OGRH_Read.UseConsume(consumeData)
  if not consumeData then return end
  
  -- Check if already buffed - exit early if so
  local hasPrimary = consumeData.primarySpellId and OGRH_Read.HasConsumeBuff(consumeData.primarySpellId)
  local hasSecondary = consumeData.secondarySpellId and OGRH_Read.HasConsumeBuff(consumeData.secondarySpellId)
  
  if hasPrimary or hasSecondary then
    OGRH_Read.Msg("You already have this buff")
    return
  end
  
  -- Try secondary first if allowed, then primary
  local itemToUse = nil
  local itemName = nil
  
  if consumeData.allowAlternate and consumeData.secondaryId then
    -- Search for secondary item in bags
    for bag = 0, 4 do
      for slot = 1, GetContainerNumSlots(bag) do
        local link = GetContainerItemLink(bag, slot)
        if link then
          local _, _, itemId = string.find(link, "item:(%d+)")
          if itemId and tonumber(itemId) == consumeData.secondaryId then
            itemToUse = {bag = bag, slot = slot}
            itemName = consumeData.secondaryName
            break
          end
        end
      end
      if itemToUse then break end
    end
  end
  
  -- If no secondary found, look for primary
  if not itemToUse and consumeData.primaryId then
    for bag = 0, 4 do
      for slot = 1, GetContainerNumSlots(bag) do
        local link = GetContainerItemLink(bag, slot)
        if link then
          local _, _, itemId = string.find(link, "item:(%d+)")
          if itemId and tonumber(itemId) == consumeData.primaryId then
            itemToUse = {bag = bag, slot = slot}
            itemName = consumeData.primaryName
            break
          end
        end
      end
      if itemToUse then break end
    end
  end
  
  -- Use the item
  if itemToUse then
    UseContainerItem(itemToUse.bag, itemToUse.slot)
    OGRH_Read.Msg("Using " .. (itemName or "consume"))
    
    -- Update status after short delay
    CreateFrame("Frame"):SetScript("OnUpdate", function()
      if not this.delay then
        this.delay = 0.5
      else
        this.delay = this.delay - arg1
        if this.delay <= 0 then
          if OGRH_Read.UpdateConsumeDisplay then
            OGRH_Read.UpdateConsumeDisplay()
          end
          this:SetScript("OnUpdate", nil)
        end
      end
    end)
  else
    OGRH_Read.Msg("You don't have this consume in your bags")
  end
end
