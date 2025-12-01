-- OGRH_MainUI.lua - OG-ReadHelper Main User Interface
if not OGRH_Read then
  DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Error: OGRH_MainUI requires OGRH_Core to be loaded first!|r")
  return
end

-- Ensure saved variables are initialized
OGRH_Read.EnsureSV()

-- Main UI window
local Main = CreateFrame("Frame", "OGRH_Read_Main", UIParent)
Main:SetWidth(180)
Main:SetHeight(32)  -- Height: 4 (top margin) + 20 (button) + 4 (bottom margin) + 4 (edge)
Main:SetPoint("CENTER", UIParent, "CENTER", -380, 120)
Main:SetFrameStrata("HIGH")
Main:SetBackdrop({
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  edgeSize = 12,
  insets = {left = 4, right = 4, top = 4, bottom = 4}
})
Main:SetBackdropColor(0, 0, 0, 0.85)
Main:EnableMouse(true)
Main:SetMovable(true)
Main:RegisterForDrag("LeftButton")
Main:SetScript("OnDragStart", function()
  OGRH_Read.EnsureSV()
  if not OGRH_Read_SV.ui.locked then
    Main:StartMoving()
  end
end)
Main:SetScript("OnDragStop", function()
  Main:StopMovingOrSizing()
  OGRH_Read.EnsureSV()
  if not OGRH_Read_SV.ui then
    OGRH_Read_SV.ui = {}
  end
  local p, _, r, x, y = Main:GetPoint()
  OGRH_Read_SV.ui.point = p
  OGRH_Read_SV.ui.relPoint = r
  OGRH_Read_SV.ui.x = x
  OGRH_Read_SV.ui.y = y
end)

-- Ensure UI settings exist
OGRH_Read.EnsureSV()
if not OGRH_Read_SV.ui then
  OGRH_Read_SV.ui = {locked = false}
end

-- Header row container
local H = CreateFrame("Frame", nil, Main)
H:SetPoint("TOPLEFT", Main, "TOPLEFT", 4, -4)
H:SetPoint("TOPRIGHT", Main, "TOPRIGHT", -4, -4)
H:SetHeight(20)

-- RH button (opens menu)
local rhBtn = CreateFrame("Button", nil, H, "UIPanelButtonTemplate")
rhBtn:SetWidth(28)
rhBtn:SetHeight(20)
rhBtn:SetPoint("LEFT", H, "LEFT", 2, 0)
rhBtn:SetText("RH")
OGRH_Read.StyleButton(rhBtn)

rhBtn:SetScript("OnClick", function()
  if OGRH_Read.ShowMinimapMenu then
    OGRH_Read.ShowMinimapMenu(rhBtn)
  end
end)

-- Sync button
local syncBtn = CreateFrame("Button", nil, H, "UIPanelButtonTemplate")
syncBtn:SetWidth(35)
syncBtn:SetHeight(20)
syncBtn:SetPoint("LEFT", rhBtn, "RIGHT", 2, 0)
syncBtn:SetText("Sync")
OGRH_Read.StyleButton(syncBtn)

syncBtn:SetScript("OnClick", function()
  -- Check if in raid
  if GetNumRaidMembers() == 0 then
    OGRH_Read.Msg("You must be in a raid to sync")
    return
  end
  
  -- Send sync request to raid (RaidHelper will respond)
  SendAddonMessage("OGRH", "READHELPER_SYNC_REQUEST", "RAID")
  OGRH_Read.Msg("Requesting encounter data from raid leader...")
end)

-- Lock button
local btnLock = CreateFrame("Button", nil, H, "UIPanelButtonTemplate")
btnLock:SetWidth(20)
btnLock:SetHeight(20)
btnLock:SetPoint("RIGHT", H, "RIGHT", -4, 0)
OGRH_Read.StyleButton(btnLock)

-- Update lock button appearance
local function UpdateLockButton()
  OGRH_Read.EnsureSV()
  if OGRH_Read_SV.ui and OGRH_Read_SV.ui.locked then
    btnLock:SetText("L")
    -- Green when locked
    btnLock:SetBackdropColor(0.2, 0.5, 0.2, 1)
  else
    btnLock:SetText("L")
    -- Default yellow when unlocked
    btnLock:SetBackdropColor(0.25, 0.35, 0.35, 1)
  end
end

btnLock:SetScript("OnClick", function()
  OGRH_Read.EnsureSV()
  if not OGRH_Read_SV.ui then
    OGRH_Read_SV.ui = {}
  end
  OGRH_Read_SV.ui.locked = not OGRH_Read_SV.ui.locked
  UpdateLockButton()
end)

-- Encounter button (fills remaining space)
local encounterBtn = CreateFrame("Button", nil, H, "UIPanelButtonTemplate")
encounterBtn:SetHeight(20)
encounterBtn:SetPoint("LEFT", syncBtn, "RIGHT", 2, 0)
encounterBtn:SetPoint("RIGHT", btnLock, "LEFT", -2, 0)
encounterBtn:SetText("Encounter")
OGRH_Read.StyleButton(encounterBtn)

encounterBtn:SetScript("OnClick", function()
  -- Display announcement in local chat
  if OGRH_Read.syncData and OGRH_Read.syncData.announcement then
    local lines = OGRH_Read.syncData.announcement
    if lines and table.getn(lines) > 0 then
      for i = 1, table.getn(lines) do
        if lines[i] and lines[i] ~= "" then
          DEFAULT_CHAT_FRAME:AddMessage("|cffffd100OG-RH:|r " .. lines[i])
        end
      end
    else
      OGRH_Read.Msg("No announcement data available")
    end
  else
    OGRH_Read.Msg("No encounter synced. Click Sync to get encounter data.")
  end
end)

encounterBtn:SetScript("OnEnter", function()
  if OGRH_Read.ShowAnnouncementTooltip then
    OGRH_Read.ShowAnnouncementTooltip(this)
  end
end)

encounterBtn:SetScript("OnLeave", function()
  GameTooltip:Hide()
end)

-- Encounter navigation row (second row)
local encounterRow = CreateFrame("Frame", nil, Main)
encounterRow:SetPoint("TOPLEFT", H, "BOTTOMLEFT", 0, -2)
encounterRow:SetPoint("TOPRIGHT", H, "BOTTOMRIGHT", 0, -2)
encounterRow:SetHeight(20)
encounterRow:Hide()  -- Hidden by default until encounter is selected

-- Store references
OGRH_Read.MainUI = {
  frame = Main,
  rhBtn = rhBtn,
  syncBtn = syncBtn,
  lockBtn = btnLock,
  encounterBtn = encounterBtn,
  encounterRow = encounterRow
}

-- Function to request sync if in raid and no encounter set
local function RequestSyncIfNeeded()
  if GetNumRaidMembers() > 0 and not OGRH_Read.syncData then
    SendAddonMessage("OGRH", "READHELPER_SYNC_REQUEST", "RAID")
  end
end

-- Register for raid roster events
Main:RegisterEvent("RAID_ROSTER_UPDATE")
Main:RegisterEvent("PARTY_MEMBERS_CHANGED")
Main:SetScript("OnEvent", function()
  if event == "RAID_ROSTER_UPDATE" then
    local numRaid = GetNumRaidMembers()
    if numRaid == 0 then
      -- Left raid - clear sync data and UI
      OGRH_Read.syncData = nil
      encounterBtn:SetText("Encounter")
      if OGRH_Read_ConsumeDisplay then
        OGRH_Read_ConsumeDisplay:Hide()
      end
    else
      -- In raid - request sync when joining raid or if no encounter set
      RequestSyncIfNeeded()
    end
  elseif event == "PARTY_MEMBERS_CHANGED" then
    -- Also check on party changes in case we drop from raid to party
    if GetNumRaidMembers() == 0 and OGRH_Read.syncData then
      OGRH_Read.syncData = nil
      encounterBtn:SetText("Encounter")
      if OGRH_Read_ConsumeDisplay then
        OGRH_Read_ConsumeDisplay:Hide()
      end
    end
  end
end)

-- Initialize
UpdateLockButton()
Main:Show()

-- Request sync on load if in raid
RequestSyncIfNeeded()
