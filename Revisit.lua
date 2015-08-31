-----------------------------------------------------------------------------------------------
-- Client Lua Script for Revisit
-- Copyright (c) 2015 PlasmaJohn.

-- Permission is hereby granted, free of charge, to any person obtaining a copy 
-- of this software and associated documentation files (the "Software"), to deal 
-- in the Software without restriction, including without limitation the rights 
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies 
-- of the Software, and to permit persons to whom the Software is furnished to do 
-- so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
-- IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- Revisit Module Definition
-----------------------------------------------------------------------------------------------
local Revisit = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999

local knSaveVersion = 2

-- OneVersion Support
local Major, Minor, Patch, Suffix = 1, 0, 5, 0
local REVISIT_CURRENT_VERSION = string.format("%d.%d.%d", Major, Minor, Patch)

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Revisit:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	
	o.tSavedData = {
		nSaveVersion = knSaveVersion,
		friendList = {
			[0] = {},
			[1] = {},
		}
	}
	
	o.tWindowData = {
		nSaveVersion = knSaveVersion,
		nLeft = 100,
		nTop = 100,
		nWidth = 400,
		nHeight = 400,
		nOpen = false,
		bLocked = false,
		bDebug= false,
	}
	
	o.nCount = 1
	
	o.nFaction = 2
	
	o.sName = ""
	
	-- see CheckLoadData
	o.bSettingsLoading = false
	o.bCharLoaded = false
	o.bCharSettingsLoaded = false
	o.bRealmSettingsLoaded = false
	o.bDataInited = false
	
	o.nSettingsPollCount = 0
	
    return o
end

function Revisit:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 
function Revisit:OnSave(eType)
	if eType == GameLib.CodeEnumAddonSaveLevel.Character then
		self:UpdateWindowData()
		return self.tWindowData
	elseif eType == GameLib.CodeEnumAddonSaveLevel.Realm then
		return self.tSavedData
	end

	return
end

function Revisit:OnRestore(eType, tSavedData)
	self:DebugPrint(string.format("Revisit:OnRestore: %d",eType))
	self.bSettingsLoading = true
	
	if tSavedData and eType == GameLib.CodeEnumAddonSaveLevel.Character then
		self.tWindowData = tSavedData
		self.bCharSettingsLoaded = true
	elseif tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.tSavedData = tSavedData
		self.bRealmSettingsLoaded = true
	end
	
end

function Revisit:CheckLoaded()
	self:DebugPrint(string.format("Revist: waited %d seconds.",2*self.nSettingsPollCount))

	-- check to see if the Player Unit is valid yet
	-- this can fail in high lag situations like
	-- first login or joining a PvP instance
	me = GameLib.GetPlayerUnit()
	if me == nil then
		self:DebugPrint("Revisit: Char load wait.")
		return false
	end
	
		if not self.bSettingsLoading then
			self:DebugPrint("Revisit: Restore hasn't started yet.  Assuming fresh install.")
			return true
		end
	
		if not self.bCharSettingsLoaded then
			self:DebugPrint("Revisit: Waiting for char level settings to restore.")
			return false
		end
	
		if not self.bRealmSettingsLoaded then
			self:DebugPrint("Revisit: Waiting for realm level settings to restore.")
			return false
		end
	
	return true
end

function Revisit:OnLoadSettings()

	-- HACK
	--
	-- we're only going to wait 8 seconds for
	-- any saved data restoration
	
	self.nSettingsPollCount = self.nSettingsPollCount + 1	

	-- Until CRB comes up with a better way to determine
	-- when the Restore stage is done I need to poll to
	-- see if the settings are done.  Will give up after
	-- 6 seconds.
	if self.nSettingsPollCount < 3 and not self:CheckLoaded() then
		return false
	end
		
	if self.LoadSettingsTimer ~= nil then
		self.LoadSettingsTimer:Stop()
	end

	self.sName = me:GetName()
	
	if me:GetFaction() ~= Unit.CodeEnumFaction.DominionPlayer then
		self.nFaction = 1
	end
	
	self:DebugPrint(string.format("Revisit: Faction=%d",self.nFaction))
	
	-- Load data
	self:DebugPrint("Revisit:OnLoadSettings: Running!")
	
	self:InitSettings()
	self:UpdateFriendGrid()
	
	-- Put the main Window back where it was
	self.wndMain:Move(self.tWindowData.nLeft,self.tWindowData.nTop,self.tWindowData.nWidth,self.tWindowData.nHeight)

	-- Center the Settings Window
	-- 350w 280h
	local t = Apollo.GetDisplaySize()
	self.wndSettings:Move((t.nWidth-350)/2,(t.nHeight-280)/2,350,280)
	
	self:CheckOpen()
	
	self.bDataInited = true
	
	Print("Revisit Loaded")
	
	return true
end

-----------------------------------------------------------------------------------------------
-- Revisit OnLoad
-----------------------------------------------------------------------------------------------
function Revisit:OnLoad()
    -- load our form file
	Apollo.LoadSprites("RevisitSprite.xml", "RevisitSprite")
	self.xmlDoc = XmlDoc.CreateFromFile("Revisit.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- Revisit OnDocLoaded
-----------------------------------------------------------------------------------------------
function Revisit:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "RevisitForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
		self.wndSettings = Apollo.LoadForm(self.xmlDoc, "ConfigForm", nil, self)
		if self.wndSettings == nil then
			Apollo.AddAddonErrorText(self, "Could not load the settings window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)
	    self.wndSettings:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterEventHandler("ChangeWorld", "OnChangeWorld", self)
		Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
		Apollo.RegisterEventHandler("ToggleAddon_Revisit", "OnRevisitOn", self)

		Apollo.RegisterSlashCommand("revisit", "OnRevisitOn", self)

		-- Do additional Addon initialization here
		self.friendGrid = self.wndMain:FindChild("FriendsGrid")
		self.visitPane = self.wndMain:FindChild("VisitPane")
		self.visitEditBox = self.wndMain:FindChild("VisitEditBox")
		
		-- update the title
		self.wndMain:FindChild("Title"):SetText(string.format("Revisit v%s",REVISIT_CURRENT_VERSION))

		-- be a lil noisy
		Print("Revisit is loading.")
		
		-- Load data
		if not self:OnLoadSettings() then
			self.LoadSettingsTimer = ApolloTimer.Create(2.0, true, "OnLoadSettings", self)
		end
		
	end
end

function Revisit:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "Revisit", {"ToggleAddon_Revisit", "", "spr_Revisit"})
	Event_FireGenericEvent("OneVersion_ReportAddonInfo", "Revisit", Major, Minor, Patch)
end

-----------------------------------------------------------------------------------------------
-- Revisit Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function Revisit:DebugPrint(sMessage)
	if self.tWindowData.bDebug== true then
		Print(sMessage)
	end
end

-- on SlashCommand "/revisit"
function Revisit:OnRevisitOn(...)
	if arg[2] then
		i=0
		tTok = {}
		for sTok in string.gmatch(arg[2],"[^%s]+") do
			tTok[i] = sTok
			i=i+1
		end
		if i==0 then
			if HousingLib.IsHousingWorld() and not self.wndMain:IsShown() then
				self.wndMain:Invoke() -- show the window
				self.tWindowData.nOpen = true
			end
		elseif i<1 or tTok[0] == "help" then
			Print("USAGE: /revisit firstname [lastname]       (visit player)")
			Print("USAGE: /revisit visit firstname [lastname] (visit player)")
			Print("USAGE: /revisit add firstname [lastname]   (add player to list)")
		elseif tTok[0] == "add" then
			value=""
			if i==2 then
				value=tTok[1]
			else
				value=string.format("%s %s",tTok[1],tTok[2])
			end
			self:DebugPrint(string.format("adding: %s",value))
			self:Add(value)
		elseif tTok[0] == "visit" then
			-- skip 'visit', 1 indexed
			value=table.concat(tTok," ",1)
			self:DebugPrint(string.format("visiting(1): %s",value))
			HousingLib.RequestVisitPlayer(value)
		else
			-- 0 indexed
			value=table.concat(tTok," ",0)
			self:DebugPrint(string.format("visiting(2): %s",value))
			HousingLib.RequestVisitPlayer(value)
		end
	else
		if HousingLib.IsHousingWorld() then
			if self.wndMain:IsShown() then
				self.wndMain:Close() -- show the window
				self.tWindowData.nOpen = false
			else
				self.wndMain:Invoke() -- show the window
				self.tWindowData.nOpen = true
			end
		end
	end
end

function Revisit:CheckOpen()
	if self.tWindowData.nOpen == true and not self.wndMain:IsShown() then
		self.wndMain:Invoke()
	end        
end

-- This event fires after player has changed instance servers,
-- like when entering or exiting a dungeon. Does not fire when 
-- player first enters game world from the character screen, as 
-- the UI and AddOns load after the player has entered. AddOns 
-- must register for this event. Does not fire when UI is reloaded. 
function Revisit:OnChangeWorld()
	if HousingLib.IsHousingWorld() then
		self:CheckOpen()
	else
		if self.wndMain:IsShown() then
			self.wndMain:Close()
		end
	end	
end

-----------------------------------------------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------------------------------------------
function Revisit:UpdateWindowData()
	if(self.wndMain == nil) then
		self:DebugPrint("Revisit:UpdateWindowData: nil wndMain")
		return
	end
	
	local nLeft,nTop,nRight,nBottom = self.wndMain:GetRect()
	
	if(nLeft == nil) then
		self:DebugPrint("Revisit:UpdateWindowData: nil rect")
		return
	end

	self:DebugPrint("Revisit:UpdateWindowData: updating")

	self.tWindowData.nLeft = nLeft
	self.tWindowData.nTop = nTop
	self.tWindowData.nWidth = nRight-nLeft
	self.tWindowData.nHeight = nBottom-nTop
	self.tWindowData.nSaveVersion = knSaveVersion
end

function Revisit:Add(sOwner)
	if self.tSavedData.friendList[self.nFaction][sOwner] ~= nil then
		Print(string.format("Revisit: %s is already on the list!",sOwner))
	else
		self.tSavedData.friendList[self.nFaction][sOwner] = true
		self:UpdateFriendGrid()
	end
end

function Revisit:Remove(sOwner)
	if self.tSavedData.friendList[self.nFaction][sOwner] == nil then
		Print(string.format("Revisit: %s is not on the list!",sOwner))
	else
		self.tSavedData.friendList[self.nFaction][sOwner] = nil
		self:UpdateFriendGrid()
	end
end

function Revisit:InitSettings()
	local debugCB = self.wndSettings:FindChild("DebugCB")
	local lockCB = self.wndSettings:FindChild("LockCB")
	
	debugCB:SetCheck((self.tWindowData.bDebug == true))
	lockCB:SetCheck((self.tWindowData.bLock == true))
	self:SetLock((self.tWindowData.bLock == true))
end

function Revisit:UpdateFriendGrid()
	local flist = {}
	for n in pairs(self.tSavedData.friendList[self.nFaction]) do
		table.insert(flist,n)
	end
	
	table.sort(flist)
	
	self.friendGrid:DeleteAll()
	
	self.nCount=1
	for i,v in ipairs(flist) do
		if self.sName ~= v then
			self.friendGrid:AddRow("")
			self.friendGrid:SetCellText(self.nCount,1,v)
			self.nCount=self.nCount+1
		end
	end
	
	-- TODO: Restore the selected name if it still exists?
	self.friendGrid:SetCurrentRow(1)
	
end

-----------------------------------------------------------------------------------------------
-- RevisitForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function Revisit:OnVisit()
	
	row = self.friendGrid:GetCurrentRow()
	if row == nil then
		
	self:DebugPrint("Revisit:OnVisit: row is nil")
	
	else
		sFriend = self.friendGrid:GetCellText(row,1)
		self:DebugPrint(string.format("Revisit:OnVisit: %s",sFriend))

		HousingLib.RequestVisitPlayer(sFriend)
	end
end

-- when the Cancel button is clicked
function Revisit:OnCancel()
	self:DebugPrint("OnCancel()")
	
	self:UpdateWindowData()
	
	self.wndMain:Close() -- hide the window
	self.tWindowData.nOpen = false
end

function Revisit:OnHome( wndHandler, wndControl, eMouseButton )
	HousingLib.RequestTakeMeHome()
end

function Revisit:OnSettings( wndHandler, wndControl, eMouseButton )
	local bOpen = self.wndSettings:IsShown()
	self.wndSettings:Show((not bOpen),true)
	self:DebugPrint("Revisit:OnSettings")
end

function Revisit:OnVisitBox( wndHandler, wndControl, eMouseButton )
	self:DebugPrint("Revisit:OnVisitBox")

	local bShow = self.visitBoxShown ~= true
	self.visitPane:Show(bShow,true)	
	
	if bShow then
		self.visitEditBox:SetFocus()
	end
end

function Revisit:OnAdd( wndHandler, wndControl, eMouseButton )
	if not HousingLib.IsHousingWorld() then
		Print("Revisit: Not on a skyplot")
		return
	end
	
	if HousingLib.IsOnMyResidence() then
		Print("Revisit: Use [Home] to return to your plot")
		return
	end
	
	sZName = GetCurrentZoneName()	
	self:Add(sZName:match("%[(.*)%]"))
end

function Revisit:OnRemove( wndHandler, wndControl, eMouseButton )
	local friendGrid = self.wndMain:FindChild("FriendsGrid")
	
	row = friendGrid:GetCurrentRow()
	if row == nil then
		Print("Revisit: row is nil")
	else
		sFriend = friendGrid:GetCellText(row,1)
		self:DebugPrint(string.format("Revisit: removing %s",sFriend))
		self:Remove(sFriend)
	end
end

function Revisit:DoVisitBox()
	local sFriend= self.visitEditBox:GetText()
	self:DebugPrint(string.format("Revist:DoVisitBox: %s",sFriend))
	self.visitPane:Show(false,true)
	
	HousingLib.RequestVisitPlayer(sFriend)
end

function Revisit:OnVisitSubmit( wndHandler, wndControl, strText )
	self:DebugPrint("Revisit:OnVisitSubmit")
	self:DoVisitBox()
end

function Revisit:OnVisitSubmitBtn( wndHandler, wndControl, eMouseButton )
	self:DebugPrint("Revisit:OnVisitSubmitBtn")
	self:DoVisitBox()
end

function Revisit:OnVisitBoxShow( wndHandler, wndControl )
	self:DebugPrint("Revisit:OnVisitBoxShow")
	self.visitBoxShown = true
end

function Revisit:OnVisitBoxHide( wndHandler, wndControl )
	self:DebugPrint("Revisit:OnVisitBoxHide")
	self.visitEditBox:SetText("")
	self.visitBoxShown = false
end

---------------------------------------------------------------------------------------------------
-- ConfigForm Functions
---------------------------------------------------------------------------------------------------

function Revisit:OnSettingsCancel( wndHandler, wndControl, eMouseButton )
	self.wndSettings:Show(false,true)
end

function Revisit:OnDebugChange( wndHandler, wndControl, eMouseButton )
	self.tWindowData.bDebug = wndControl:IsChecked()
end

function Revisit:SetLock(bVal)
	self.tWindowData.bLock = bVal
	self.wndMain:SetStyle("Moveable",(not self.tWindowData.bLock))
	self.wndMain:SetStyle("Sizable",(not self.tWindowData.bLock))
end

function Revisit:OnLockChange( wndHandler, wndControl, eMouseButton )
	self:SetLock(wndControl:IsChecked())
end

-----------------------------------------------------------------------------------------------
-- Revisit Instance
-----------------------------------------------------------------------------------------------
local RevisitInst = Revisit:new()
RevisitInst:Init()
