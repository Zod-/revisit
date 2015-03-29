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
		nDebug = false,
	}
	
	o.nCount = 1
	
	o.nFaction = 2
	
	o.sName = ""
	
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
	if tSavedData and eType == GameLib.CodeEnumAddonSaveLevel.Character then
		self.tWindowData = tSavedData
		return
	elseif tSavedData and tSavedData.nSaveVersion == knSaveVersion then
		self.tSavedData = tSavedData
	end
	
	self.LoadSettingsTimer = ApolloTimer.Create(2.0, true, "OnLoadSettings", self)
end

function Revisit:OnLoadSettings()
	-- poll until loaded
	me = GameLib.GetPlayerUnit()
	if me == nil then
		self:DebugPrint("Revisit: Char load wait.")
		return
	end
	
	self.LoadSettingsTimer:Stop()
	
	self.sName = me:GetName()
	
	if me:GetFaction() ~= Unit.CodeEnumFaction.DominionPlayer then
		self.nFaction = 1
	end
	
	self:DebugPrint(string.format("Revisit: %d",self.nFaction))
	
	self:UpdateFriendGrid()

	self.wndMain:Move(self.tWindowData.nLeft,self.tWindowData.nTop,self.tWindowData.nWidth,self.tWindowData.nHeight)

	self:CheckOpen()
end

-----------------------------------------------------------------------------------------------
-- Revisit OnLoad
-----------------------------------------------------------------------------------------------
function Revisit:OnLoad()
    -- load our form file
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
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterEventHandler("ChangeWorld", "OnChangeWorld", self)
		Apollo.RegisterSlashCommand("revisit", "OnRevisitOn", self)

		-- Do additional Addon initialization here
	end
end

-----------------------------------------------------------------------------------------------
-- Revisit Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

function Revisit:DebugPrint(sMessage)
	if self.tWindowData.nDebug == true then
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
			self.wndMain:Invoke() -- show the window
			self.tWindowData.nOpen = true
		elseif i<2 or tTok[0] ~= "add" then
			Print("USAGE: /revisit add firstname [lastname]")
		elseif i==2 then
			self:DebugPrint(string.format("arg2: %s %s",tTok[0],tTok[1]))
			self:Add(tTok[1])
		else
			self:DebugPrint(string.format("arg2: %s %s %s",tTok[0],tTok[1],tTok[2]))
			self:Add(string.format("%s %s",tTok[1],tTok[2]))
		end
	else
		self.wndMain:Invoke() -- show the window
		self.tWindowData.nOpen = true
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

function Revisit:UpdateFriendGrid()
	local flist = {}
	for n in pairs(self.tSavedData.friendList[self.nFaction]) do
		table.insert(flist,n)
	end
	
	table.sort(flist)
	
	local friendGrid = self.wndMain:FindChild("FriendsGrid")
	friendGrid:DeleteAll()
	
	self.nCount=1
	for i,v in ipairs(flist) do
		if self.sName ~= v then
			friendGrid:AddRow("")
			friendGrid:SetCellText(self.nCount,1,v)
			self.nCount=self.nCount+1
		end
	end
	
	-- TODO: Restore the selected name if it still exists?
	friendGrid:SetCurrentRow(1)
	
end

-----------------------------------------------------------------------------------------------
-- RevisitForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function Revisit:OnVisit()
	local friendGrid = self.wndMain:FindChild("FriendsGrid")
	
	row = friendGrid:GetCurrentRow()
	if row == nil then
		
	self:DebugPrint("Revisit:OnVisit: row is nil")
	
	else
		sFriend = friendGrid:GetCellText(row,1)
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

-----------------------------------------------------------------------------------------------
-- Revisit Instance
-----------------------------------------------------------------------------------------------
local RevisitInst = Revisit:new()
RevisitInst:Init()
