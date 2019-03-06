--[[

	Clock: a simple in-game clock window
		copyright 2004 by Telo / Modified by Arnvid for ACUI

	- Displays the time in a small, movable window
	- Displays time-based character information in a tooltip on mouseover

  - updated for 1700
  - updated for 10900
  - updated for 11000
  - updated for 11100
  
]]

--------------------------------------------------------------------------------------------------
-- Localizable strings
--------------------------------------------------------------------------------------------------

CLOCK = "Clock";
BINDING_NAME_TOGGLECLOCK = "Toggle Clock";
TIME_PLAYED_SESSION = "Time played this session: %s"; -- The amount of time played this session
CLOCK_TIME_DAY = "%d day";
CLOCK_TIME_HOUR = "%d hour";
CLOCK_TIME_MINUTE = "%d minute";
CLOCK_TIME_SECOND = "%d second";
EXP_PER_HOUR_LEVEL = "Experience per hour this level: %.2f";
EXP_PER_HOUR_SESSION = "Experience per hour this session: %.2f";
EXP_TO_LEVEL = "Experience to level: %d (%.2f%% to go)";
TIME_TO_LEVEL_LEVEL = "Time to level at this level's rate: %s";
TIME_TO_LEVEL_SESSION = "Time to level at this session's rate: %s";
TIME_INFINITE = "infinite";
HEALTH_PER_SECOND = "Health regenerated per second: %d";
MANA_PER_SECOND = "Mana regenerated per second: %d";

CLOCK_HELP = "help";			-- must be lowercase; displays help
CLOCK_STATUS = "status";		-- must be lowercase; shows status
CLOCK_FREEZE = "freeze";		-- must be lowercase; freezes the clock in position
CLOCK_UNFREEZE = "unfreeze";	-- must be lowercase; unfreezes the clock so that it can be dragged
CLOCK_RESET = "reset";			-- must be lowercase; resets the clock to its default position
CLOCK_24_HOUR = "24-hour";		-- must be lowercase; sets the clock to 24 hour time display
CLOCK_12_HOUR = "12-hour";		-- must be lowercase; sets the clock to 12 hour time display

CLOCK_STATUS_HEADER = "|cffffff00Clock status:|r";
CLOCK_FROZEN = "Clock: frozen in place";
CLOCK_UNFROZEN = "Clock: unfrozen and can be dragged";
CLOCK_RESET_DONE = "Clock: position reset to default";
CLOCK_SET_24 = "Clock: 24-hour time display";
CLOCK_SET_12 = "Clock: 12-hour time display";
CLOCK_TIME_OFFSET = "Clock: displayed time is offset by %s%02d:%02d";
CLOCK_TIME_ERROR = "Clock: unable to determine a valid offset from that input";

CLOCK_HELP_TEXT0 = " ";
CLOCK_HELP_TEXT1 = "|cffffff00Clock command help:|r";
CLOCK_HELP_TEXT2 = "|cff00ff00Use |r|cffffffff/clock <command>|r|cff00ff00 to perform the following commands:|r";
CLOCK_HELP_TEXT3 = "|cffffffff"..CLOCK_HELP.."|r|cff00ff00: displays this message.|r";
CLOCK_HELP_TEXT4 = "|cffffffff"..CLOCK_STATUS.."|r|cff00ff00: displays status information about the current option settings.|r";
CLOCK_HELP_TEXT5 = "|cffffffff"..CLOCK_FREEZE.."|r|cff00ff00: freezes the Clock so that it can't be dragged.|r";
CLOCK_HELP_TEXT6 = "|cffffffff"..CLOCK_UNFREEZE.."|r|cff00ff00: unfreezes the Clock so that it can be dragged.|r";
CLOCK_HELP_TEXT7 = "|cffffffff"..CLOCK_RESET.."|r|cff00ff00: resets the Clock to its default position.|r";
CLOCK_HELP_TEXT8 = "|cffffffff"..CLOCK_24_HOUR.."|r|cff00ff00: displays the time in 24-hour format.|r";
CLOCK_HELP_TEXT9 = "|cffffffff"..CLOCK_12_HOUR.."|r|cff00ff00: displays the time in 12-hour format.|r";
CLOCK_HELP_TEXT10 = "|cff00ff00Anything else is interpreted as the offset from server time that is applied to the time displayed.|r";
CLOCK_HELP_TEXT11 = "|cff00ff00Supported formats include -:30, +11, 5:30, 0, etc.|r";
CLOCK_HELP_TEXT12 = " ";
CLOCK_HELP_TEXT13 = "|cff00ff00For example: |r|cffffffff/clock +2|r|cff00ff00 will adjust the displayed time to two hours later than server time.|r";

--------------------------------------------------------------------------------------------------
-- Local variables
--------------------------------------------------------------------------------------------------

local TotalTimePlayed = 0;
local LevelTimePlayed = 0;
local SessionTimePlayed = 0;
local ElapsedSinceLastPlayedMessage = 0;
local NeedPlayedMessage = 1;

local localInitialXP;
local localSessionXP = 0;
local localRolloverXP = 0;

local localHealthSecondTimer = 0;
local localInitialHealth;
local localHealthPerSecond;
local localManaSecondTimer = 0;
local localInitialMana;
local localManaPerSecond;

local localInCombat;

local lBeingDragged;

-- the current server
local lServer;

--------------------------------------------------------------------------------------------------
-- Global variables
--------------------------------------------------------------------------------------------------

-- Constants
CLOCK_UPDATE_RATE = 0.1;

--------------------------------------------------------------------------------------------------
-- Internal functions
--------------------------------------------------------------------------------------------------

local function Clock_Status()
	DEFAULT_CHAT_FRAME:AddMessage(CLOCK_STATUS_HEADER);
	if( ClockState ) then
		if( ClockState.Freeze ) then
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_FROZEN);
		else
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_UNFROZEN);
		end
		if( ClockState.MilitaryTime ) then
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_SET_24);
		else
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_SET_12);
		end
		local hour;
		local minute;
		local sign;
		if( ClockState.Servers[lServer].OffsetHour ) then
			hour = ClockState.Servers[lServer].OffsetHour;
		else
			hour = 0;
		end
		if( ClockState.Servers[lServer].OffsetMinute ) then
			minute = ClockState.Servers[lServer].OffsetMinute;
		else
			minute = 0;
		end
		if( hour < 0 or minute < 0 ) then
			sign = "-";
		else
			sign = "+";
		end
		DEFAULT_CHAT_FRAME:AddMessage(format(CLOCK_TIME_OFFSET, sign, hour, minute));
	else
		DEFAULT_CHAT_FRAME:AddMessage(CLOCK_UNFROZEN);
		DEFAULT_CHAT_FRAME:AddMessage(CLOCK_SET_12);
		DEFAULT_CHAT_FRAME:AddMessage(format(CLOCK_TIME_OFFSET, "+", 0, 0));
	end
end

local function Clock_Reset()
	ClockFrame:ClearAllPoints();
	ClockFrame:SetPoint("TOP", "UIParent", "TOP", 0, 0);
end

function Clock_SlashCommandHandler(msg)
	if( msg ) then
		local command = string.lower(msg);
		if( command == "" or command == CLOCK_HELP ) then
			local index = 0;
			local value = getglobal("CLOCK_HELP_TEXT"..index);
			while( value ) do
				DEFAULT_CHAT_FRAME:AddMessage(value);
				index = index + 1;
				value = getglobal("CLOCK_HELP_TEXT"..index);
			end
		elseif( command == CLOCK_STATUS ) then
			Clock_Status();
		elseif( command == CLOCK_FREEZE ) then
			ClockState.Freeze = 1;
			Clock_OnDragStop();
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_FROZEN);
		elseif( command == CLOCK_UNFREEZE ) then
			ClockState.Freeze = nil;
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_UNFROZEN);
		elseif( command == CLOCK_RESET ) then
			Clock_Reset();
			Clock_OnDragStop();
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_RESET_DONE);
		elseif( command == CLOCK_24_HOUR ) then
			ClockState.MilitaryTime = 1;
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_SET_24);
		elseif( command == CLOCK_12_HOUR ) then
			ClockState.MilitaryTime = nil;
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_SET_12);
		else
			local s, e, sign, hour, minute = string.find(command, "^([+-]?)(%d*):?(%d*)$");
			if( hour or minute ) then
				if( not hour or hour == "" ) then
					hour = 0;
				end
				if( not minute or minute == "" ) then
					minute = 0;
				end
				if( string.len(hour) <= 2 and string.len(minute) <= 2 ) then
					if( sign and sign == "-" ) then
						ClockState.Servers[lServer].OffsetHour = -(hour + 0);
						ClockState.Servers[lServer].OffsetMinute = -(minute + 0);
					else
						sign = "+";
						ClockState.Servers[lServer].OffsetHour = hour + 0;
						ClockState.Servers[lServer].OffsetMinute = minute + 0;
					end
					DEFAULT_CHAT_FRAME:AddMessage(format(CLOCK_TIME_OFFSET, sign, hour, minute));
					return;
				end
			end
			DEFAULT_CHAT_FRAME:AddMessage(CLOCK_TIME_ERROR);
		end
	end
end

local function Clock_ResetHealth()
	localHealthSecondTimer = 0;
	localInitialHealth = UnitHealth("player");
end

local function Clock_ResetMana()
	localManaSecondTimer = 0;
	localInitialMana = UnitMana("player");
end

local function Clock_ParsePosition(position)
	local x, y, z;
	local iStart, iEnd;

	iStart, iEnd, x, y, z = string.find(position, "^(.-), (.-), (.-)$");
	if( z ) then
		return x + 0.0, y + 0.0, z + 0.0;
	end
	return nil, nil, nil;
end

--------------------------------------------------------------------------------------------------
-- OnFoo functions
--------------------------------------------------------------------------------------------------

function Clock_OnLoad()
	this:RegisterForDrag("LeftButton");

	-- RegisterForSave("ClockState");

	-- Register our slash command
	SLASH_CLOCK1 = "/clock";
	SlashCmdList["CLOCK"] = function(msg)
		Clock_SlashCommandHandler(msg);
	end
	
	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("TIME_PLAYED_MSG");
	this:RegisterEvent("PLAYER_LEVEL_UP");
	this:RegisterEvent("PLAYER_ENTERING_WORLD");
	this:RegisterEvent("PLAYER_XP_UPDATE");
	this:RegisterEvent("UNIT_HEALTH");
	this:RegisterEvent("UNIT_MANA");
	this:RegisterEvent("PLAYER_ENTER_COMBAT");
	this:RegisterEvent("PLAYER_LEAVE_COMBAT");
	
	ClockFrame.TimeSinceLastUpdate = 0;

	if( DEFAULT_CHAT_FRAME ) then
		DEFAULT_CHAT_FRAME:AddMessage("ACUI/Telo's Clock AddOn loaded");
	end
	UIErrorsFrame:AddMessage("ACUI/Telo's Clock AddOn loaded", 1.0, 1.0, 1.0, 1.0, UIERRORS_HOLD_TIME);
end

function Clock_OnUpdate(arg1)
	SessionTimePlayed = SessionTimePlayed + arg1;
	ElapsedSinceLastPlayedMessage = ElapsedSinceLastPlayedMessage + arg1;
	
	localHealthSecondTimer = localHealthSecondTimer + arg1;
	localManaSecondTimer = localManaSecondTimer + arg1;
	
	if( localHealthSecondTimer >= 1 and localInitialHealth ) then
		if( UnitHealth("player") < UnitHealthMax("player") ) then
			local hps = UnitHealth("player") - localInitialHealth;
			if( hps > 0 ) then
				localHealthPerSecond = hps / localHealthSecondTimer;
			end
		end
		Clock_ResetHealth();
	end
	
	if( localManaSecondTimer >= 1 and localInitialMana ) then
		if( UnitMana("player") < UnitManaMax("player") ) then
			local mps = UnitMana("player") - localInitialMana;
			if( mps > 0 ) then
				localManaPerSecond = mps / localManaSecondTimer;
			end
		end
		Clock_ResetMana();
	end
	
	ClockFrame.TimeSinceLastUpdate = ClockFrame.TimeSinceLastUpdate + arg1;
	if( ClockFrame.TimeSinceLastUpdate > CLOCK_UPDATE_RATE ) then
		ClockText:SetText(Clock_GetTimeText());
		if( GameTooltip:IsOwned(this) ) then
			Clock_SetTooltip();
		end
		ClockFrame.TimeSinceLastUpdate = 0;
	end
end

function Clock_OnEvent()
	if( event == "TIME_PLAYED_MSG" ) then
		TotalTimePlayed = arg1;
		LevelTimePlayed = arg2;
		ElapsedSinceLastPlayedMessage = 0;
		NeedPlayedMessage = 0;
		
		-- Sync up all of the times to the session time; this makes
		-- the tooltip look nicer as everything changes all at once
		local fraction = SessionTimePlayed - floor(SessionTimePlayed);
		TotalTimePlayed = floor(TotalTimePlayed) + fraction;
		LevelTimePlayed = floor(LevelTimePlayed) + fraction;
		
		if( GameTooltip:IsOwned(this) ) then
			Clock_SetTooltip();
		end
	elseif( event == "PLAYER_LEVEL_UP" ) then
		LevelTimePlayed = SessionTimePlayed - floor(SessionTimePlayed);
		localRolloverXP = localSessionXP;
		localInitialXP = 0;
		if( GameTooltip:IsOwned(this) ) then
			Clock_SetTooltip();
		end
	elseif( event == "PLAYER_ENTERING_WORLD" ) then
		if( not localInitialXP ) then
			localInitialXP = UnitXP("player");
		end
		Clock_ResetHealth();
		Clock_ResetMana();
	elseif( event == "PLAYER_XP_UPDATE" ) then
		if( localInitialXP ) then
			localSessionXP = UnitXP("player") - localInitialXP + localRolloverXP;
		end
	elseif( event == "UNIT_HEALTH" ) then
		if( arg1 == "player" ) then
			if( not localInitialHealth or UnitHealth("player") - localInitialHealth < 0 ) then
				Clock_ResetHealth();
			end
		end
	elseif( event == "UNIT_MANA" ) then
		if( arg1 == "player" ) then
			if( not localInitialMana or UnitMana("player") - localInitialMana < 0 ) then
				Clock_ResetMana();
			end
		end
	elseif( event == "PLAYER_ENTER_COMBAT" ) then
		localInCombat = 1;
	elseif( event == "PLAYER_LEAVE_COMBAT" ) then
		localInCombat = nil;
	elseif( event == "VARIABLES_LOADED" ) then
		if( not ClockState ) then
			ClockState = { };
			DEFAULT_CHAT_FRAME:AddMessage("ACUI/Telo's Clock AddOn - variables cleared and reset!!!");
		end
		if( not ClockState.Servers ) then
			ClockState.Servers = { };
		end

		lServer = GetCVar("realmName");
		if( not ClockState.Servers[lServer] ) then
			ClockState.Servers[lServer] = { };
		end
		
		-- Convert old global time offset data into data for the current server
		if( ClockState.OffsetHour or ClockState.OffsetMinute ) then
			ClockState.Servers[lServer].OffsetHour = ClockState.OffsetHour;
			ClockState.Servers[lServer].OffsetMinute = ClockState.OffsetMinute;
			ClockState.OffsetHour = nil;
			ClockState.OffsetMinute = nil;
		end
	end
end

function ClockText_OnEnter()
	GameTooltip:SetOwner(ClockFrame, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOP", "UIParent", "TOP", 0, -32);
	if( NeedPlayedMessage == 1 ) then
		RequestTimePlayed();
	end
	Clock_SetTooltip();
end

function Clock_OnDragStart()
	if( not ClockState or not ClockState.Freeze ) then
		ClockFrame:StartMoving()
		lBeingDragged = 1;
	end
end

function Clock_OnDragStop()
	ClockFrame:StopMovingOrSizing()
	lBeingDragged = nil;
end

-- Helper functions
function Clock_GetTimeText()
	local hour, minute = GetGameTime();
	local pm;
	
	if( ClockState ) then
		if( ClockState.Servers[lServer].OffsetHour ) then
			hour = hour + ClockState.Servers[lServer].OffsetHour;
		end
		if( ClockState.Servers[lServer].OffsetMinute ) then
			minute = minute + ClockState.Servers[lServer].OffsetMinute;
		end
	end
	if( minute > 59 ) then
		minute = minute - 60;
		hour = hour + 1
	elseif( minute < 0 ) then
		minute = 60 + minute;
		hour = hour - 1;
	end
	if( hour > 23 ) then
		hour = hour - 24;
	elseif( hour < 0 ) then
		hour = 24 + hour;
	end
	
	if( ClockState and ClockState.MilitaryTime ) then
		return format(TEXT(TIME_TWENTYFOURHOURS), hour, minute);
	else
		if( hour >= 12 ) then
			pm = 1;
			hour = hour - 12;
		else
			pm = 0;
		end
		if( hour == 0 ) then
			hour = 12;
		end
		if( pm == 1 ) then
			return format(TEXT(TIME_TWELVEHOURPM), hour, minute);
		else
			return format(TEXT(TIME_TWELVEHOURAM), hour, minute);
		end
	end
end

local function Clock_FormatPart(fmt, val)
	local part;
	
	part = format(TEXT(fmt), val);
	if( val ~= 1 ) then
		part = part.."s";
	end
	
	return part;
end

function Clock_FormatTime(time)
	local d, h, m, s;
	local text = "";
	local skip = 1;

	d, h, m, s = ChatFrame_TimeBreakDown(time);
	if( d > 0 ) then
		text = text..Clock_FormatPart(CLOCK_TIME_DAY, d)..", ";
		skip = 0;
	end
	if( (skip == 0) or (h > 0) ) then
		text = text..Clock_FormatPart(CLOCK_TIME_HOUR, h)..", ";
		skip = 0;
	end
	if( (skip == 0) or (m > 0) ) then
		text = text..Clock_FormatPart(CLOCK_TIME_MINUTE, m)..", ";
		skip = 0;
	end
	if( (skip == 0) or (s > 0) ) then
		text = text..Clock_FormatPart(CLOCK_TIME_SECOND, s);
	end
	
	return text;
end

function Clock_SetTooltip()
	local total, level, session;
	local xpPerHourLevel, xpPerHourSession;
	local xpTotal, xpCurrent, xpToLevel;
	local text;
	
	total = format(TEXT(TIME_PLAYED_TOTAL), Clock_FormatTime(TotalTimePlayed + ElapsedSinceLastPlayedMessage));
	level = format(TEXT(TIME_PLAYED_LEVEL), Clock_FormatTime(LevelTimePlayed + ElapsedSinceLastPlayedMessage));
	session = format(TEXT(TIME_PLAYED_SESSION), Clock_FormatTime(SessionTimePlayed));
	
	if( NeedPlayedMessage == 1 ) then
		text = session;
	else
		text = total.."\n"..level.."\n"..session;
	end
	
	if( (LevelTimePlayed + ElapsedSinceLastPlayedMessage > 0) or SessionTimePlayed > 0 ) then
		text = text.."\n";
	end
	if( LevelTimePlayed + ElapsedSinceLastPlayedMessage > 0 ) then
		xpPerHourLevel = UnitXP("player") / ((LevelTimePlayed + ElapsedSinceLastPlayedMessage) / 3600);
		text = text.."\n"..format(TEXT(EXP_PER_HOUR_LEVEL), xpPerHourLevel);
	else
		xpPerHourLevel = 0;
	end
	if( SessionTimePlayed > 0 ) then
		xpPerHourSession = localSessionXP / (SessionTimePlayed / 3600);
		text = text.."\n"..format(TEXT(EXP_PER_HOUR_SESSION), xpPerHourSession);
	else
		xpPerHourSession = 0;
	end
	
	xpTotal = UnitXPMax("player");
	xpCurrent = UnitXP("player");
	if( xpCurrent < xpTotal ) then
		xpToLevel = xpTotal - xpCurrent;
		text = text.."\n"..format(TEXT(EXP_TO_LEVEL), xpToLevel, (xpToLevel / xpTotal) * 100);
		if( xpPerHourLevel > 0 ) then
			text = text.."\n"..format(TEXT(TIME_TO_LEVEL_LEVEL), Clock_FormatTime((xpToLevel / xpPerHourLevel) * 3600));
		else
			text = text.."\n"..format(TEXT(TIME_TO_LEVEL_LEVEL), TEXT(TIME_INFINITE));
		end
		if( xpPerHourSession > 0 ) then
			text = text.."\n"..format(TEXT(TIME_TO_LEVEL_SESSION), Clock_FormatTime((xpToLevel / xpPerHourSession) * 3600));
		else
			text = text.."\n"..format(TEXT(TIME_TO_LEVEL_SESSION), TEXT(TIME_INFINITE));
		end
	end
	
	if( localHealthPerSecond or localManaPerSecond ) then
		text = text.."\n";
	end
	if( localHealthPerSecond ) then
		text = text.."\n"..format(TEXT(HEALTH_PER_SECOND), localHealthPerSecond);
	end
	if( localManaPerSecond ) then
		text = text.."\n"..format(TEXT(MANA_PER_SECOND), localManaPerSecond);
	end

	GameTooltip:SetText(text);
end
