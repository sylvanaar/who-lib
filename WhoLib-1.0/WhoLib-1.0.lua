--[[
Name: WhoLib-1.0
Revision: $Revision$
Author(s): ALeX Kazik (alx@kazik.de)
Website: http://wowace.com/wiki/WhoLib-1.0
Documentation: http://wowace.com/wiki/WhoLib-1.0
SVN: svn://dev.wowace.com/wowace/trunk/WhoLib/
Description: Queing of /who and SendWho() queries and a much better interface, with gurantee to be executed & callback.
License: http://creativecommons.org/licenses/by-nc-sa/2.5/
Dependencies: AceLibrary, AceEvent-2.0, AceHook-2.1, AceOO-2.0, AceLocale-2.2, Deformat
]]

-- VISIT: http://wowace.com/wiki/WhoLib-1.0

local MAJOR_VERSION = 'WhoLib-1.0'
local MINOR_VERSION = 90000 + tonumber(('$Revision$'):match("(%d+)"))

if not AceLibrary then error(MAJOR_VERSION .. ' requires AceLibrary') end
if not AceLibrary:IsNewVersion(MAJOR_VERSION, MINOR_VERSION) then return end

if not AceLibrary:HasInstance('AceEvent-2.0') then error(MAJOR_VERSION .. ' requires AceEvent-2.0.') end
if not AceLibrary:HasInstance('AceHook-2.1') then error(MAJOR_VERSION .. ' requires AceHook-2.1') end
if not AceLibrary:HasInstance('AceOO-2.0') then error(MAJOR_VERSION .. ' requires AceOO-2.0') end
if not AceLibrary:HasInstance('AceLocale-2.2') then error(MAJOR_VERSION .. ' requires AceLocale-2.2') end

local AceOO = AceLibrary:GetInstance('AceOO-2.0')
local lib = AceOO.Mixin {
				'Who',
				'UserInfo',
				'CachedUserInfo',
				'WHOLIB_QUEUE_USER',
				'WHOLIB_QUEUE_QUIET',
				'WHOLIB_QUEUE_SCANNING',
				'WHOLIB_FLAG_ALLWAYS_CALLBACK',
				'SetWhoLibDebug',
			}

local _G = getfenv(0)

local WHOS_TO_DISPLAY = _G.WHOS_TO_DISPLAY

-- externals

function lib.Who(handler, query, opts)
	local self = WhoLibByALeX
	local args = {}

	if(type(query) ~= 'string')then
		self:error('query must be a string')
	end
	args.query = query
	if(opts == nil)then
		opts = {}
	elseif(type(opts) ~= 'table')then
		self:error('opts must be a table')
	end
	if(opts.flags == nil)then
		args.flags = 0
	elseif(type(opts.flags) ~= 'number')then
		self:error('opts.flags must be a number')
	else
		args.flags = opts.flags
	end
	if(opts.queue == nil)then
		args.queue = self.WHOLIB_QUEUE_SCANNING
	elseif(opts.queue ~= self.WHOLIB_QUEUE_USER and opts.queue ~= self.WHOLIB_QUEUE_QUIET and opts.queue ~= self.WHOLIB_QUEUE_SCANNING)then
		self:error('opts.queue is not a valid queue')
	else
		args.queue = opts.queue
	end
	if(type(opts.callback) == 'function')then
		args.callback = opts.callback
	elseif(type(opts.callback) == 'string')then
		-- method
		if(opts.handler == nil)then
			opts.handler = handler
		end
		if(type(opts.handler) ~= 'table')then
			self:error('opts.handler must be a table')
		end
		if(type(opts.handler[opts.callback]) ~= 'function')then
			self:error('object opts.hander do not have an method "%s" (opts.callback)', opts.callback)
		end
		args.handler = opts.handler
		args.callback = opts.callback
	elseif(opts.callback ~= nil)then
		self:error('opts.callback must be either function, string or nil')
	end
	
	-- now args - copied and verified from opts
	
	if(opts.queue == self.WHOLIB_QUEUE_USER)then
		if(WhoFrame:IsShown())then
			self:GuiWho(opts.query)
		else
			self:ConsoleWho(opts.query)
		end
	else
		self:AskWho(args)
	end
end

function lib.UserInfo(handler, name, opts)
	local self = WhoLibByALeX
	local now = time()
	local args = {}
	
	if(type(name) ~= 'string')then
		self:error('name must be a string')
	end

	local bytes, pos = {string.byte(name,1,-1)}, 1
	while(bytes[pos+1] and bit.band(bytes[pos+1], 0xc0) == 0x80)do
		pos = pos + 1
	end
	args.name = string.upper(string.sub(name, 1, pos)) .. string.lower(string.sub(name, pos+1))

	if(opts == nil)then
		opts = {}
	elseif(type(opts) ~= 'table')then
		self:error('opts must be a string or a table')
	end
	if(opts.queue == nil)then
		args.queue = self.WHOLIB_QUEUE_SCANNING
	elseif(opts.queue ~= self.WHOLIB_QUEUE_QUIET and opts.queue ~= self.WHOLIB_QUEUE_SCANNING)then
		self:error('opts.queue is not a valid queue')
	else
		args.queue = opts.queue
	end
	if(opts.timeout == nil)then
		args.timeout = 5
	elseif(type(opts.timeout) ~= 'number')then
		self:error('opts.timeout must be a number')
	else
		args.timeout = opts.timeout
	end
	if(opts.flags == nil)then
		args.flags = 0
	elseif(type(opts.flags) ~= 'number')then
		self:error('opts.flags must be a number')
	else
		args.flags = opts.flags
	end
	if(type(opts.callback) == 'function')then
		args.callback = opts.callback
	elseif(type(opts.callback) == 'string')then
		-- method
		if(opts.handler == nil)then
			opts.handler = handler
		end
		if(type(opts.handler) ~= 'table')then
			self:error('opts.handler must be a table')
		end
		if(type(opts.handler[opts.callback]) ~= 'function')then
			self:error('object opts.hander do not have an method "' .. opts.callback .. '" (opts.callback)')
		end
		args.handler = opts.handler
		args.callback = opts.callback
	elseif(opts.callback ~= nil)then
		self:error('opts.callback must be either table, string or nil')
	end
	
	-- now args - copied and verified from opts
	
	if(self.Cache[args.name] ~= nil)then
		-- user is in cache
		if(self.Cache[args.name].valid == true and (args.timeout < 0 or self.Cache[args.name].last + args.timeout*60 > now))then
			-- cache is valid and timeout is in range
			if(self.Debug)then
				DEFAULT_CHAT_FRAME:AddMessage('WhoLib: Info(' .. args.name ..') returned immedeatly')
			end
			if(bit.band(args.flags, self.WHOLIB_FLAG_ALLWAYS_CALLBACK) ~= 0)then
				if(type(args.callback) == 'function')then
					args.callback(self.Cache[args.name].data)
				elseif(type(args.callback) == 'string')then
					args.handler[args.callback](args.handler, self.Cache[args.name].data)
				end
				return false
			else
				return self:ReturnUserInfo(name)
			end
		elseif(self.Cache[args.name].valid == false)then
			-- query is already running (first try)
			if(args.callback ~= nil)then
				tinsert(self.Cache[args.name].callback, args)
			end
			if(self.Debug)then
				DEFAULT_CHAT_FRAME:AddMessage('WhoLib: Info(' .. args.name ..') returned cause it\'s already searching')
			end
			return nil
		end
	else
		self.Cache[args.name] = {valid=false, inqueue=false, callback={}, data={Name = args.name}}
	end
	if(self.Cache[args.name].inqueue)then
		-- query is running!
		if(args.callback ~= nil)then
			tinsert(self.Cache[args.name].callback, args)
		end
		if(self.Debug)then
			DEFAULT_CHAT_FRAME:AddMessage('WhoLib: Info(' .. args.name ..') returned cause it\'s already searching')
		end
		return nil
	end
	local query = 'n-"' .. args.name .. '"'
	self.Cache[args.name].inqueue = true
	if(args.callback ~= nil)then
		tinsert(self.Cache[args.name].callback, args)
	end
	self.CacheQueue[query] = args.name
	if(self.Debug)then
		DEFAULT_CHAT_FRAME:AddMessage('WhoLib: Info(' .. args.name ..') added to queue')
	end
	self:AskWho( { query = query, queue = args.queue, flags = 0, info = args.name } )
	return nil
end

function lib.CachedUserInfo(handler, name)
	local self = WhoLibByALeX
	
	if(type(name) ~= 'string')then
		self:error('name must be a string')
	end

	local bytes, pos = {string.byte(name,1,-1)}, 1
	while(bytes[pos+1] and bit.band(bytes[pos+1], 0xc0) == 0x80)do
		pos = pos + 1
	end
	name = string.upper(string.sub(name, 1, pos)) .. string.lower(string.sub(name, pos+1))

	if(self.Cache[name] == nil)then
		return nil
	else
		return self:ReturnUserInfo(name)
	end
end

function lib.SetWhoLibDebug(handler, mode)
	local self = WhoLibByALeX
	
	self.Debug = mode
end

-- internals

function lib:AskWhoNext()
	local args = nil
	for k,v in ipairs(self.Queue) do
		if(WhoFrame:IsShown() and k > self.WHOLIB_QUEUE_QUIET)then
			break
		end
		if(#v > 0)then
			args = tremove(v, 1)
			break
		end
	end
	if(args)then
		self.WhoInProgress = true
		self.Result = {}
		self.Args = args
		self.Total = -1
		if(args.console_show == true)then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(self.L['console_query'], args.query), 1, 1, 0)
		end
		if(args.queue == self.WHOLIB_QUEUE_USER)then
			WhoFrameEditBox:SetText(args.query)
		end
		if(args.queue == self.WHOLIB_QUEUE_QUIET or args.queue == self.WHOLIB_QUEUE_SCANNING)then
			self.hooks.SetWhoToUI(1)
			self.Quiet = true
		elseif(args.gui == true)then
			self.hooks.SetWhoToUI(1)
		else
			self.hooks.SetWhoToUI(0)
		end
		self.hooks.SendWho(args.query)
	else
		self.WhoInProgress = false
	end
end

function lib:AskWho(args)
	tinsert(self.Queue[args.queue], args)
	if(self.Debug)then
		DEFAULT_CHAT_FRAME:AddMessage('WhoLib: [' .. args.queue .. '] added "' .. args.query .. '", queues=' .. #self.Queue[1] .. '/'.. #self.Queue[2] .. '/'.. #self.Queue[3])
	end
	if(WhoLibFu)then
		WhoLibFu:Update()
	end
	if(not self.WhoInProgress)then
		self:AskWhoNext()
	end
end

function lib:ReturnWho()
	if(self.Args.queue == self.WHOLIB_QUEUE_QUIET or self.Args.queue == self.WHOLIB_QUEUE_SCANNING)then
		self.Quiet = nil
	end
	if(self.Debug)then
		DEFAULT_CHAT_FRAME:AddMessage('WhoLib: [' .. self.Args.queue .. '] returned "' .. self.Args.query .. '", total=' .. self.Total ..' , queues=' .. #self.Queue[1] .. '/'.. #self.Queue[2] .. '/'.. #self.Queue[3])
	end
	local now = time()
	local complete = self.Total == #self.Result
	for _,v in pairs(self.Result)do
		if(self.Cache[v.Name] == nil)then
			self.Cache[v.Name] = { inqueue = false, callback = {} }
		end
		self.Cache[v.Name].valid = true -- is now valid
		self.Cache[v.Name].data = v -- update data
		self.Cache[v.Name].data.Online = true -- player is online
		self.Cache[v.Name].last = now -- update timestamp
		if(self.Cache[v.Name].inqueue)then
			if(self.Args.info and self.CacheQueue[self.Args.query] == v.Name)then
				-- found by the query which was created to -> remove us from query
				self.CacheQueue[self.Args.query] = nil
			else
				-- found by another query
				for k2,v2 in pairs(self.CacheQueue) do
					if(v2 == v.Name)then
						self.CacheQueue[k2] = nil
						for i=self.WHOLIB_QUEUE_QUIET, self.WHOLIB_QUEUE_SCANNING do
							for k3,v3 in pairs(self.Queue[i]) do
								if(v3.query == k2 and v3.info)then
									-- remove the query which was generated for this user, cause another query was faster...
									table.remove(self.Queue[i], k3)
								end
							end
						end
					end
				end
			end
			if(self.Debug)then
				DEFAULT_CHAT_FRAME:AddMessage('WhoLib: Info(' .. v.Name ..') returned: on')
			end
			for _,v2 in pairs(self.Cache[v.Name].callback) do
				if(type(v2.callback) == 'function')then
					v2.callback(self:ReturnUserInfo(v.Name))
				elseif(type(v2.callback) == 'string')then
					v2.handler[v2.callback](v2.handler, self:ReturnUserInfo(v.Name))
				end
			end
			self.Cache[v.Name].callback = {}
		end
		self.Cache[v.Name].inqueue = false -- query is done
	end
	if(self.Args.info and self.CacheQueue[self.Args.query] ~= nil)then
		-- the query did not deliver the result => not online!
		local name = self.CacheQueue[self.Args.query]
		if(self.Cache[name].inqueue)then
			-- nothing found (yet)
			self.Cache[name].valid = true -- is now valid
			self.Cache[name].inqueue = false -- query is done?
			self.Cache[name].last = now -- update timestamp
			if(complete)then
				self.Cache[name].data.Online = false -- player is offline
			else
				self.Cache[name].data.Online = nil -- player is unknown (more results from who than can be displayed)
			end
		end
		if(self.Debug)then
			DEFAULT_CHAT_FRAME:AddMessage('WhoLib: Info(' .. name ..') returned: ' .. (self.Cache[name].data.Online == false and 'off' or 'unkn'))
		end
		for _,v in pairs(self.Cache[name].callback) do
			if(type(v.callback) == 'function')then
				v.callback(self:ReturnUserInfo(name))
			elseif(type(v.callback) == 'string')then
				v.handler[v.callback](v.handler, self:ReturnUserInfo(name))
			end
		end
		self.Cache[name].callback = {}
		self.CacheQueue[self.Args.query] = nil
	end
	if(type(self.Args.callback) == 'function')then
		self.Args.callback(self.Args.query, self:dup(self.Result), complete, self.Args.info)
	elseif(type(self.Args.callback) == 'string')then
		self.Args.handler[self.Args.callback](self.Args.handler, self.Args.query, self:dup(self.Result), complete, self.Args.info)
	end
	self:TriggerEvent('WHOLIB_QUERY_RESULT', self.Args.query, self:dup(self.Result), complete, self.Args.info)
	self:ScheduleEvent(self.AskWhoNext, 5, self)
	if(WhoLibFu)then
		WhoLibFu:Update()
	end
end

function lib:GuiWho(msg)
	if(msg == self.L['gui_wait'])then
		return
	end

	local q1count = #self.Queue[self.WHOLIB_QUEUE_USER]
	for _,v in pairs(self.Queue[self.WHOLIB_QUEUE_USER]) do
		if(v.gui == true)then
			return
		end
	end
	if(self.WhoInProgress)then
		WhoFrameEditBox:SetText(self.L['gui_wait'])
	end
	self.savedText = msg
	self:AskWho({query = msg, queue = self.WHOLIB_QUEUE_USER, flags = 0, gui = true})
	WhoFrameEditBox:ClearFocus();
end

function lib:ConsoleWho(msg)
	WhoFrameEditBox:SetText(msg)
	local console_show = false
	local q1count = #self.Queue[self.WHOLIB_QUEUE_USER]
	if(q1count > 0 and self.Queue[self.WHOLIB_QUEUE_USER][q1count][q] == msg)then -- last query is itdenical: drop
		return
	end
	if(q1count == 1 and self.Queue[self.WHOLIB_QUEUE_USER][1].console_show == false)then -- display 'queued' if console and not yet shown
		DEFAULT_CHAT_FRAME:AddMessage(string.format(self.L['console_queued'], self.Queue[self.WHOLIB_QUEUE_USER][1].query), 1, 1, 0)
		self.Queue[self.WHOLIB_QUEUE_USER][1].console_show = true
	end
	if(q1count > 0)then
		DEFAULT_CHAT_FRAME:AddMessage(string.format(self.L['console_queued'], msg), 1, 1, 0)
		console_show = true
	end
	self:AskWho({query = msg, queue = self.WHOLIB_QUEUE_USER, flags = 0, console_show = console_show})
end

function lib:ReturnUserInfo(name)
	if(name ~= nil and self ~= nil and self.Cache ~= nil and self.Cache[name] ~= nil) then
		return self:dup(self.Cache[name].data), (time() - self.Cache[name].last) / 60 
	end
end

function lib:dup(from)
	local to = {}
	for k,v in pairs(from) do
		if(type(v) == 'table')then
			to[k] = self:dup(v)
		else
			to[k] = v
		end
	end

	return to
end

-- hooks

function lib:SendWho(msg)
	self:AskWho({query = msg, queue = (self.SetWhoToUIState == 1) and self.WHOLIB_QUEUE_QUIET or self.WHOLIB_QUEUE_USER, flags = 0})
end

function lib:WhoFrameEditBox_OnEnterPressed()
	self:GuiWho(WhoFrameEditBox:GetText())
end

function lib:FriendsFrame_OnEvent(this, event, ...)
	if(not (event == 'WHO_LIST_UPDATE' and self.Quiet))then
		self.hooks.FriendsFrame_OnEvent(this, event, ...)
	end
end

function lib:CloseWhoFrame()
	if(not self.WhoInProgress)then
		self:AskWhoNext()
	end
end

function lib:SetWhoToUI(state)
	self.SetWhoToUIState = state
end

-- new '/who' function

local function SlashWHO(msg)
	self = WhoLibByALeX
	
	if(msg == '')then
		self:GuiWho(WhoFrame_GetDefaultWhoCommand())
	elseif(WhoFrame:IsVisible())then
		self:GuiWho(msg)
	else
		self:ConsoleWho(msg)
	end
end

-- /wholibdebug: debug on/off; I decided not to use the AceConsole, since it's not neesed and requies less memory

local function SlashDebug()
	self = WhoLibByALeX
	
	self.Debug = not self.Debug
	DEFAULT_CHAT_FRAME:AddMessage('WhoLib: Debugging is now ' .. (self.Debug and 'on' or 'off'))
end

-- events

function lib:CHAT_MSG_SYSTEM(arg1)
	if not arg1 then return end

	local pla, _, lvl, rac, cla, gui, zon = self.Deformat:Deformat(arg1, WHO_LIST_GUILD_FORMAT)
	if(pla ~= nil)then
		tinsert(self.Result, {Name=pla, Guild=gui, Level=lvl, Race=rac, Class=cla, Zone=zon})
	else
		local pla, _, lvl, rac, cla, zon = self.Deformat:Deformat(arg1, WHO_LIST_FORMAT)
		if(pla ~= nil)then
			tinsert(self.Result, {Name=pla, Guild='', Level=lvl, Race=rac, Class=cla, Zone=zon})
		else
			local numWhoResults = self.Deformat:Deformat(arg1, WHO_NUM_RESULTS)
			if(numWhoResults ~= nil)then
				self.Total = numWhoResults
				self:ReturnWho()
			end
		end
	end
end

function lib:WHO_LIST_UPDATE()
	local num
	self.Total, num = GetNumWhoResults()
	for i=1, num do
		local charname, guildname, level, race, class, zone = GetWhoInfo(i)
		self.Result[i] = {Name=charname, Guild=guildname, Level=level, Race=race, Class=class, Zone=zone}
	end
	
	self:ReturnWho()
end

-- init

local function activate(self, oldLib, oldDeactivate)
	WhoLibByALeX = self

	self.Queue = oldLib and oldLib.Queue or {[1]={}, [2]={}, [3]={}}
	self.SlashWho = oldLib and oldLib.SlashWho or SlashCmdList['WHO']
	self.WhoInProgress = oldLib and oldLib.WhoInProgress or false
	self.Result = oldLib and oldLib.Result or nil
	self.Args = oldLib and oldLib.Args or nil
	self.Total = oldLib and oldLib.Total or nil
	self.Quiet = oldLib and oldLib.Quiet or nil
	self.Debug = oldLib and oldLib.Debug or false
	self.Cache = oldLib and oldLib.Cache or {}
	self.CacheQueue = oldLib and oldLib.CacheQueue or {}
	self.SetWhoToUIState = oldLib and oldLib.SetWhoToUIState or 0
	self.hooks = oldLib and oldLib.hooks or {} -- Copy hooks from the lib we're upgrading
	
	SlashCmdList['WHO'] = SlashWHO
	
	SlashCmdList['WHOLIB_DEBUG'] = SlashDebug
	SLASH_WHOLIB_DEBUG1 = '/wholibdebug'
	
	--WhoLibByALeX = self
	
	self.L = AceLibrary('AceLocale-2.2'):new('WhoLib-1.0.$Revision$')
	
	self.L:RegisterTranslations('enUS', function() return {
		['console_queued'] = 'Added "/who %s" to queue',
		['console_query'] = 'Result of "/who %s"',
		['gui_wait'] = '- Please Wait -',
	} end )
	
	self.L:RegisterTranslations('ruRU', function() return {
		['console_queued'] = 'Добавлено в очередь "/who %s"',
		['console_query'] = 'Результат "/who %s"',
		['gui_wait'] = '- Пожалуйста подождите -',
	} end )
	
	-- queues
	self.WHOLIB_QUEUE_USER = 1
	self.WHOLIB_QUEUE_QUIET = 2
	self.WHOLIB_QUEUE_SCANNING = 3

	-- bit masks!
	self.WHOLIB_FLAG_ALLWAYS_CALLBACK = 1
	
	if(oldDeactivate)then
		oldDeactivate(oldLib)
	end

	_G.WhoLibByALeX = WhoLibByALeX
end

local function deactivate(oldLib)
	oldLib:CancelAllScheduledEvents()
	oldLib:UnregisterAllEvents()
	oldLib:UnhookAll()
end

local function external(self, major, instance)
	if(major == 'AceEvent-2.0')then
		instance:embed(self)
		self:CancelAllScheduledEvents()
		self:RegisterEvent('CHAT_MSG_SYSTEM')
		self:RegisterEvent('WHO_LIST_UPDATE')
	elseif(major == 'AceHook-2.1')then
		instance:embed(self)
		-- If we're upgrading we may have already hooked these so we check first
		if not self:IsHooked('SendWho') then 			
			self:Hook('SendWho', true) 
		end
		if not self:IsHooked('WhoFrameEditBox_OnEnterPressed') then
			self:Hook('WhoFrameEditBox_OnEnterPressed', true)
		end
		if not self:IsHooked('FriendsFrame_OnEvent') then
			self:Hook('FriendsFrame_OnEvent', true)
		end
		if not self:IsHooked('SetWhoToUI') then
			self:Hook('SetWhoToUI', true)
		end
		if not self:IsHooked(WhoFrame, 'Hide') then
			self:SecureHook(WhoFrame, 'Hide', 'CloseWhoFrame')
		end
	elseif(major == 'Deformat-2.0')then
		self.Deformat = instance
	end
end

AceLibrary:Register(lib, MAJOR_VERSION, MINOR_VERSION, activate, deactivate, external)

lib = nil


