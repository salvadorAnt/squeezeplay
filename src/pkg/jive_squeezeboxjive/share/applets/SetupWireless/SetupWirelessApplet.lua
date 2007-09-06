

-----------------------------------------------------------------------------
-- Convention: functions/methods starting with t_ are executed in the thread
-----------------------------------------------------------------------------



-- stuff we use
local assert, getmetatable, ipairs, pairs, pcall, setmetatable, tonumber, tostring, type = assert, getmetatable, ipairs, pairs, pcall, setmetatable, tonumber, tostring, type

local oo                     = require("loop.simple")

local io                     = require("io")
local os                     = require("os")
local string                 = require("string")
local table                  = require("jive.utils.table")
local debug                  = require("jive.utils.debug")

local Applet                 = require("jive.Applet")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local Tile                   = require("jive.ui.Tile")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Textinput              = require("jive.ui.Textinput")
local Window                 = require("jive.ui.Window")
local Popup                  = require("jive.ui.Popup")

local Wireless               = require("jive.net.Wireless")

local log                    = require("jive.utils.log").logger("applets.setup")

local jnt                    = jnt

local EVENT_ACTION           = jive.ui.EVENT_ACTION
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP
local LAYER_FRAME            = jive.ui.LAYER_FRAME
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE

local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE

local EVENT_KEY_PRESS        = jive.ui.EVENT_KEY_PRESS
local EVENT_WINDOW_POP       = jive.ui.EVENT_WINDOW_POP
local EVENT_WINDOW_ACTIVE    = jive.ui.EVENT_WINDOW_ACTIVE
local EVENT_WINDOW_INACTIVE  = jive.ui.EVENT_WINDOW_INACTIVE
local EVENT_CONSUME          = jive.ui.EVENT_CONSUME
local EVENT_UNUSED           = jive.ui.EVENT_UNUSED

local KEY_FWD         = jive.ui.KEY_FWD
local KEY_REW         = jive.ui.KEY_REW
local KEY_GO          = jive.ui.KEY_GO
local KEY_BACK        = jive.ui.KEY_BACK
local KEY_UP          = jive.ui.KEY_UP
local KEY_DOWN        = jive.ui.KEY_DOWN
local KEY_LEFT        = jive.ui.KEY_LEFT
local KEY_RIGHT       = jive.ui.KEY_RIGHT



-- configuration
local CONNECT_TIMEOUT = 20


module(...)
oo.class(_M, Applet)



function init(self)
	self.t_ctrl = Wireless(jnt, "eth0")
end


function setupRegionShow(self, setupNext)
	local wlan = self.t_ctrl

	local window = Window("window", self:string("NETWORK_REGION"))

	local region = wlan:getRegion()

	local menu = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorAlpha)

	for name in wlan:getRegionNames() do
		local item = {
			text = self:string("NETWORK_REGION_" .. name),
			callback = function()
					   if region ~= name then
						   wlan:setRegion(name)
					   end
					   setupNext()
				   end
		}

		menu:addItem(item)
		if region == name then
			log:warn("setSelectedItem=", menu:numItems())
			menu:setSelectedItem(item)
		end
		log:warn("region=", region, " name=", name)
	end


	window:addWidget(Textarea("help", self:string("NETWORK_REGION_HELP")))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function settingsRegionShow(self)
	local wlan = self.t_ctrl

	local window = Window("window", self:string("NETWORK_REGION"))

	local region = wlan:getRegion()

	local menu = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorAlpha)

	local group = RadioGroup()
	for name in wlan:getRegionNames() do
		log:warn("region=", region, " name=", name)
		menu:addItem({
				     text = self:string("NETWORK_REGION_" .. name),
				     icon = RadioButton("radio", group,
							function() wlan:setRegion(name) end,
							region == name
						)
			     })
	end

	window:addWidget(Textarea("help", self:string("NETWORK_REGION_HELP")))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function _setCurrentSSID(self, ssid)
	if self.currentSSID == ssid then
		return
	end

	if self.currentSSID and self.scanResults[self.currentSSID] then
		local item = self.scanResults[self.currentSSID].item
		item.style = nil
		self.scanMenu:updatedItem(item)
	end

	self.currentSSID = ssid

	if self.currentSSID then
		local item = self.scanResults[self.currentSSID].item
		item.style = "current"
		self.scanMenu:updatedItem(item)
	end
end


function _addNetwork(self, ssid)
	local item = {
		text = ssid,
		icon = Icon("icon"),
		callback = function()
				   openNetwork(self, ssid)
			   end,
		weight = 1
	}
		      
	self.scanResults[ssid] = {
		item = item,            -- menu item
		-- flags = nil,         -- beacon flags
		-- bssid = nil,         -- bssid if know from scan
		-- id = nil             -- wpa_ctrl id if configured
	}

	self.scanMenu:addItem(item)
end


function setupScanShow(self, setupNext)
	local window = Popup("popupIcon")

	window:addWidget(Icon("iconConnecting"))
	window:addWidget(Label("text", self:string("NETWORK_FINDING_NETWORKS")))

	-- wait for network scan (in network thred)
	self.t_ctrl:scan(setupNext)

	-- or timeout after 10 seconds if no networks are found
	window:addTimer(10000, function() setupNext() end)

	self:tieAndShowWindow(window)
	return window
end


function setupNetworksShow(self, setupNext)
	self.setupNext = setupNext

	return _networksShow(self, self:string("NETWORK_WIRELESS_NETWORKS"), self:string("NETWORK_SETUP_HELP"))
end


function settingsNetworksShow(self)
	self.setupNext = nil

	return setupScanShow(self, function()
					   _networksShow(self, self:string("NETWORK"), self:string("NETWORK_SETTINGS_HELP"))
				   end)
end


function _networksShow(self, title, help)
	local window = Window("window", title)

	-- window to return to on completion of network settings
	self.topWindow = window

	self.scanMenu = SimpleMenu("menu")
	self.scanMenu:setComparator(SimpleMenu.itemComparatorWeightAlpha)

	self.scanMenu:addItem({
				      text = self:string("NETWORK_ENTER_ANOTHER_NETWORK"),
				      callback = function()
							 enterSSID(self)
						 end,
				      weight = 2
			      })
	
	
	self.scanResults = {}

	-- load known networks (in network thread)
	jnt:perform(function()
			    self:t_listNetworks()
		    end)

	-- process existing scan results
	self:_scanComplete(self.t_ctrl:scanResults())

	-- schedule network scan 
	self.scanMenu:addTimer(5000, function() self:_scan() end)

	local help = Textarea("help", help)
	window:addWidget(help)
	window:addWidget(self.scanMenu)

	self:tieAndShowWindow(window)
	return window
end


-- load known networks from wpa supplicant into scan menu
function t_listNetworks(self)
	local networkResults = self.t_ctrl:request("LIST_NETWORKS")
	log:warn("list results ", networkResults)

	-- update the ui in the main thread
	jnt:t_perform(function()
	      for id, ssid, flags in string.gmatch(networkResults, "([%d]+)\t([^\t]*)\t[^\t]*\t([^\t]*)\n") do
		      if not string.match(ssid, "logitech[%-%+%*]squeezebox[%-%+%*](%x+)") then

			      if not self.scanResults[ssid] then
				      _addNetwork(self, ssid)
			      end
			      self.scanResults[ssid].id = id

			      if string.match(flags, "%[CURRENT%]") then
				      self:_setCurrentSSID(ssid)
			      end
		      end
	      end
      end)
end


function _scan(self)
	self.t_ctrl:scan(function(scanTable) _scanComplete(self, scanTable) end)
end


function _scanComplete(self, scanTable)
	local now = os.time()

	local associated = nil
	for ssid, entry in pairs(scanTable) do
		      -- hide squeezebox ad-hoc networks
		      if not string.match(ssid, "logitech[%-%+%*]squeezebox[%-%+%*](%x+)") then

			      if not self.scanResults[ssid] then
				      _addNetwork(self, ssid)

				      self.scanResults[ssid].bssid = entry.bssid
				      self.scanResults[ssid].flags = entry.flags
			      end

			      if entry.associated then
				      associated = ssid
			      end

			      local item = self.scanResults[ssid].item

			      assert(type(entry.quality) == "number", "Eh? quality is " .. tostring(entry.quality) .. " for " .. ssid)
			      item.icon:setStyle("wirelessLevel" .. entry.quality)
			      self.scanMenu:updatedItem(item)

			      -- remove networks not seen for 20 seconds
			      if not entry.associated and os.difftime(now, entry.lastScan) > 20 then
				      self.scanMenu:removeItem(item)
				      self.scanResults[ssid] = nil
			      end
		      end
	end

	-- update current ssid 
	self:_setCurrentSSID(associated)
end


function _hideToTop(self)
	if type(self.setupNext) == "function" then
		self.setupNext()
		return
	end

	if Framework.windowStack[1] == self.topWindow then
		return
	end

	while #Framework.windowStack > 2 and Framework.windowStack[2] ~= self.topWindow do
		log:warn("hiding=", Framework.windowStack[2], " topWindow=", self.topWindow)
		Framework.windowStack[2]:hide(Window.transitionPushLeft)
	end

	Framework.windowStack[1]:hide(Window.transitionPushLeft)
end


function openNetwork(self, ssid)

	if ssid == self.currentSSID then
		-- current network, show status
		if type(self.setupNext) == "function" then
			return self.setupNext()
		else
			return networkStatusShow(self)
		end

	elseif self.scanResults[ssid] and
		self.scanResults[ssid].id ~= nil then
		-- known network, give options
		return connectOrDelete(self, ssid)

	else
		-- unknown network, enter password
		self.ssid = ssid
		return enterPassword(self)
	end
end


function enterSSID(self)
	local window = Window("window", self:string("NETWORK_NETWORK_NAME"))

	local textinput = Textinput("textinput", self.ssid or "",
				    function(_, value)
					    if #value == 0 then
						    return false
					    end

					    self.ssid = value
					    enterPassword(self)

					    return true
				    end
			    )

	local help = Textarea("help", self:string("NETWORK_NETWORK_NAME_HELP"))
	window:addWidget(help)
	window:addWidget(textinput)

	self:tieAndShowWindow(window)
	return window
end


function enterPassword(self)
	assert(self.ssid, "No SSID selected")

	if self.scanResults[self.ssid] == nil then
		return chooseEncryption(self)
	end

	local flags = self.scanResults[self.ssid].flags
	log:warn("ssid is ", self.ssid, "flags is ", flags)

	if flags == "" then
		self.encryption = "none"
		return connect(self)

	elseif string.find(flags, "WPA2%-PSK") then
		log:warn("**** WPA2")
		self.encryption = "wpa2"
		return enterPSK(self)

	elseif string.find(flags, "WPA%-PSK") then
		log:warn("**** WPA")
		self.encryption = "wpa"
		return enterPSK(self)

	elseif string.find(flags, "WEP") then
		log:warn("**** WEP")
		return chooseWEPLength(self)

	elseif string.find(flags, "WPA%-EAP") or string.find(flags, "WPA2%-EAP") then
		local window = Window("window", self:string("NETWORK_CONNECTION_PROBLEM"))

		local menu = SimpleMenu("menu",
					{
						{
							text = self:string("NETWORK_GO_BACK"),
							callback = function()
									   window:hide()
								   end
						},
					})

		local help = Textarea("help", self:string("NETWORK_UNSUPPORTED_TYPES_HELP"))
--"WPA-EAP and WPA2-EAP are not supported encryption types.")

		window:addWidget(help)
		window:addWidget(menu)

		self:tieAndShowWindow(window)		
		return window

	else
		return chooseEncryption(self)

	end
end


function chooseEncryption(self)
	local window = Window("window", self:string("NETWORK_WIRELESS_ENCRYPTION"))

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_NO_ENCRYPTION"),
						callback = function()
								   self.encryption = "none"
								   createAndConnect(self)
							   end
					},
					{
						text = self:string("NETWORK_WEP_64"),
						callback = function()
								   self.encryption = "wep40"
								   enterWEPKey(self)
							   end
					},
					{
						text = self:string("NETWORK_WEP_128"),
						callback = function()
								   self.encryption = "wep104"
								   enterWEPKey(self)
							   end
					},
					{
						text = self:string("NETWORK_WPA"),
						callback = function()
								   self.encryption = "wpa"
								   enterPSK(self)
							   end
					},
					{
						text = self:string("NETWORK_WPA2"),
						callback = function()
								   self.encryption = "wpa2"
								   enterPSK(self)
							   end
					},
				})

	local help = Textarea("help", self:string("NETWORK_WIRELESS_ENCRYPTION_HELP"))
	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function chooseWEPLength(self)
	local window = Window("window", self:string("NETWORK_WIRELESS_ENCRYPTION"))

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_WEP_64"),
						callback = function()
								   self.encryption = "wep40"
								   enterWEPKey(self)
							   end
					},
					{
						text = self:string("NETWORK_WEP_128"),
						callback = function()
								   self.encryption = "wep104"
								   enterWEPKey(self)
							   end
					},
				})

	local help = Textarea("help", self:string("NETWORK_WIRELESS_ENCRYPTION_HELP"))
	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function enterWEPKey(self)
	local window = Window("window", self:string("NETWORK_WIRELESS_KEY"))

	-- create an object to hold the hex value. the methods are used
	-- by the text input widget.
	local v = {}
	setmetatable(v, {
			     __tostring =
				     function(e)
					     return table.concat(e, " ")
				     end,

			     __index = {
				     setValue =
					     function(value, str)
						     local i = 1
						     for dd in string.gmatch(str, "%x%x") do
							     value[i] = dd
							     i = i + 1
						     end
						     
					     end,

				     getValue =
					     function(value)
						     return table.concat(value)
					     end,

				     getChars = 
					     function(value, cursor)
						     return "0123456789ABCDEF"
					     end,

				     isEntered =
					     function(value, cursor)
						     return cursor == (#value * 3) - 1
					     end
			     }
		     })

	-- set the initial value
	if self.encryption == "wep40" then
		v:setValue("0000000000")
	else
		v:setValue("00000000000000000000000000")
	end


	local textinput = Textinput("textinput", v,
				    function(_, value)
					    self.key = value:getValue()
					    createAndConnect(self)

					    return true
				    end
			    )

	local help = Textarea("help", self:string("NETWORK_WIRELESS_KEY_HELP"))
--"Enter your wireless key. Scroll to change letters, press the center button to choose that letter. Press the center button twice to finish.")
	window:addWidget(help)
	window:addWidget(textinput)

	self:tieAndShowWindow(window)
	return window
end


function enterPSK(self)
	local window = Window("window", self:string("NETWORK_WIRELESS_PASSWORD"))

	local textinput = Textinput("textinput", self.psk or "",
				    function(_, value)
					    if #value < 8 then
						    -- the psk is 8 or more characters
						    return false
					    end

					    self.psk = value
					    createAndConnect(self)

					    return true
				    end
			    )

	local help = Textarea("help", self:string("NETWORK_WIRELESS_PASSWORD_HELP"))
	window:addWidget(help)
	window:addWidget(textinput)

	self:tieAndShowWindow(window)
	return window
end


function t_addNetwork(self)
	assert(self.t_ctrl, "No WPA supplicant")

	local option = {
		encryption = self.encryption,
		psk = self.psk,
		key = self.key
	}

	local id = self.t_ctrl:t_addNetwork(self.ssid, option)

	self.addNetwork = true
	self.scanResults[self.ssid].id = id
end


function _connectTimer(self)
	-- the connection is completed when we connected to the wireless
	-- network, and have an ip address. if dhcp failed this address
	-- will be self assigned.
	jnt:perform(function()
			    log:warn("connectTimeout=", self.connectTimeout, " dhcpTimeout=", self.dhcpTimeout)

			    local status = self.t_ctrl:t_wpaStatusRequest()

			    log:warn("wpa_state=", status.wpa_state)
			    log:warn("ip_address=", status.ip_address)

			    if not (status.wpa_state == "COMPLETED" and status.ip_address) then
				    -- not connected yet

				    self.connectTimeout = self.connectTimeout + 1
				    if self.connectTimeout ~= CONNECT_TIMEOUT then
					    return
				    end

				    -- connection timed out
				    jnt:t_perform(function()
							  self:connectFailed("timeout")
						  end)
				    return
			    end
			    
			    if string.match(status.ip_address, "^169.254.") then
				    -- auto ip
				    self.dhcpTimeout = self.dhcpTimeout + 1
				    if self.dhcpTimeout ~= CONNECT_TIMEOUT then
					    return
				    end

				    -- dhcp timed out
				    jnt:t_perform(function()
							  self:failedDHCP()
						  end)
			    else
				    -- dhcp completed
				    jnt:t_perform(function()
							  self:connectOK()
						  end)
			    end
		    end)
end


function _eventSink(self, chunk)
	log:warn("wpa-cli event: ", chunk)

	if string.match(chunk, "CTRL%-EVENT%-CONNECTED") then
		log:info("wireless is connected")
		--connectOK(self)

	elseif string.match(chunk, "WPA: 4%-Way Handshake failed") then
		self:connectFailed("psk")
	end
end


function t_connect(self, ssid)
	local request

	-- Force disconnect from existing network
	request = 'DISCONNECT'
	assert(self.t_ctrl:request(request) == "OK\n", "wpa_cli failed:" .. request)

	-- Force the interface down
	os.execute("/sbin/ifdown -f eth0")

	local id = self.scanResults[ssid].id
	log:warn("t_connect ssid=", ssid, " id=", id)

	if id == nil then
		-- Configuring the WLAN
		self:t_addNetwork()
	else
		local request = 'SELECT_NETWORK ' .. id
		assert(self.t_ctrl:request(request) == "OK\n", "wpa_cli failed:" .. request)
	end

	-- Allow reassociation
	request = 'REASSOCIATE'
	assert(self.t_ctrl:request(request) == "OK\n", "wpa_cli failed:" .. request)
end


function createAndConnect(self)
	log:warn("removing network")

	jnt:perform(function()
			    self:t_removeNetwork(self.ssid)
			    jnt:t_perform(function()
						  connect(self)
					  end)
		    end)
end


function connect(self, keepConfig)
	local request

	self.connectTimeout = 0
	self.dhcpTimeout = 0

	if not keepConfig then
		self:_setCurrentSSID(nil)

		-- Configuring the WLAN in the network thread
		if self.scanResults[self.ssid] == nil then
			_addNetwork(self, self.ssid)
		end

		jnt:perform(function()
				    self:t_connect(self.ssid)
			    end)
	end

	-- Progress window
	local window = Popup("popupIcon")

	local icon  = Icon("iconConnecting")
	icon:addTimer(1000, function()
				    self:_connectTimer()
			    end)
	window:addWidget(icon)

	window:addWidget(Label("text", self:string("NETWORK_CONNECTING_TO", self.ssid)))

	-- FIXME back handler...


	window:addListener(EVENT_WINDOW_ACTIVE,
			   function(event)
				   log:warn("****** ACTIVE")

				   jnt:perform(function()
						       -- Open an additional connection for wpa-cli events
						       self.e_ctrl = Wireless(jnt, "eth0")
						       self.e_ctrl:attach(function(chunk, err)
										  _eventSink(self, chunk)
									  end)
					       end)

				   return EVENT_UNUSED
			   end)

	window:addListener(EVENT_WINDOW_INACTIVE,
			   function(event)
				   log:warn("****** INACTIVE")

				   jnt:perform(function()
						       self.e_ctrl:detach()
						       self.e_ctrl = nil
					       end)

				   return EVENT_UNUSED
			   end)

	window:addListener(EVENT_KEY_PRESS,
			   function(event)
				   return EVENT_CONSUME
			   end)

	self:tieAndShowWindow(window)
	return window
end


function t_connectFailed(self)
	local request

	-- Stop trying to connect to the network
	request = 'DISCONNECT'
	assert(self.t_ctrl:request(request) == "OK\n", "wpa_cli failed:" .. request)


	log:warn("addNetwork=", self.addNetwork)
	if self.addNetwork then
		-- Remove failed network
		self:t_removeNetwork(self.ssid)

		-- Update state in main thread
		jnt:t_perform(function()
				      self.addNetwork = false
			      end)
	end
end


function connectFailed(self, reason)
	log:warn("connection failed")

	-- Stop trying to connect to the network, if this network is
	-- being added this will also remove the network configuration
	jnt:perform(function()
			    self:t_connectFailed()
		    end)


	-- Message based on failure type
	local helpText = self:string("NETWORK_CONNECTION_PROBLEM_HELP")

	if reason == "psk" then
		helpText = tostring(helpText) .. " " .. tostring(self:string("NETWORK_PROBLEM_PASSWORD_INCORRECT"))
	end


	-- popup failure
	local window = Window("window", self:string("NETWORK_CONNECTION_PROBLEM"))

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_TRY_AGAIN"),
						callback = function()
								   connect(self)
								   window:hide()
							   end
					},
					{
						text = self:string("NETWORK_TRY_DIFFERENT"),
						callback = function()
								   _hideToTop(self)
							   end
					},
					{
						text = self:string("NETWORK_GO_BACK"),
						callback = function()
								   window:hide()
							   end
					},
				})


	local help = Textarea("help", helpText)

	window:addWidget(help)
	window:addWidget(menu)

	self:tieWindow(window)
	window:show()

	return window
end


function connectOK(self)
	log:warn("connection OK ", self.ssid)

	self:_setCurrentSSID(self.ssid)

	-- forget connection state
	self.ssid = nil
	self.encryption = nil
	self.psk = nil
	self.key = nil

	-- send notification we're on a new network
	jnt:notify("networkConnected")

	-- popup confirmation
	local window = Popup("popupIcon")
	window:addWidget(Icon("iconConnected"))

	local text = Label("text", self:string("NETWORK_CONNECTED_TO", self.currentSSID))
	window:addWidget(text)

	window:addTimer(2000,
			function(event)
				_hideToTop(self)
			end)

	window:addListener(EVENT_KEY_PRESS,
			   function(event)
				   _hideToTop(self)
				   return EVENT_CONSUME
			   end)


	self:tieWindow(window)
	window:show()
	return window
end


function _parseip(str)
	local ip = 0
	for w in string.gmatch(str, "%d+") do
		ip = ip << 8
		ip = ip | tonumber(w)
	end
	return ip
end


function _ipstring(ip)
	local str = {}
	for i = 4,1,-1 do
		str[i] = string.format("%d", ip & 0xFF)
		ip = ip >> 8
	end
	str = table.concat(str, ".")
	return str
end


function _validip(str)
	local ip = _parseip(str)
	if ip == 0x00000000 or ip == 0xFFFFFFFF then
		return false
	else
		return true
	end
end


function _subnet(self)
	local ip = _parseip(self.ipAddress or "0.0.0.0")

	if ((ip & 0xC0000000) == 0xC0000000) then
		return "255.255.255.0"
	elseif ((ip & 0x80000000) == 0x80000000) then
		return "255.255.0.0"
	elseif ((ip & 0x80000000) == 0) then
		return "255.0.0.0"
	else
		return "0.0.0.0";
	end
end


function _gateway(self)
	local ip = _parseip(self.ipAddress or "0.0.0.0")
	local subnet = _parseip(self.ipSubnet or "255.255.255.0")

	return _ipstring(ip & subnet | 1)
end


function _sigusr1(process)
	local pid

	local pattern = "%s*(%d+).*" .. process

	log:warn("pattern is ", pattern)

	local cmd = io.popen("/bin/ps")
	for line in cmd:lines() do
		pid = string.match(line, pattern)
		if pid then break end
	end
	cmd:close()

	if pid then
		log:warn("kill -usr1 ", pid)
		os.execute("kill -usr1 " .. pid)
	else
		log:error("cannot sigusr1 ", process)
	end
end


function failedDHCP(self)
	local window = Window("window", self:string("NETWORK_ADDRESS_PROBLEM"))

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_TRY_AGAIN"),
						callback = function()
								   -- poke udhcpto try again
								   _sigusr1("udhcpc")
								   connect(self, true)
								   window:hide()
							   end
					},
					{
						text = self:string("ZEROCONF_ADDRESS"),
						callback = function()
								   -- already have a self assigned address, we're done
								   connectOK(self)
							   end
					},
					{
						text = self:string("STATIC_ADDRESS"),
						callback = function()
								   enterIP(self)
							   end
					},
				})


	local help = Textarea("help", self:string("NETWORK_ADDRESS_HELP"))

	window:addWidget(help)
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function enterIP(self)
	local v = Textinput.ipAddressValue(self.ipAddress or "0.0.0.0")

	local window = Window("window", self:string("NETWORK_IP_ADDRESS"))

	window:addWidget(Textarea("help", self:string("NETWORK_IP_ADDRESS_HELP")))
	window:addWidget(Textinput("textinput", v,
				   function(_, value)
					   value = value:getValue()
					   if not _validip(value) then
						   return false
					   end

					   self.ipAddress = value
					   self.ipSubnet = _subnet(self)

					   self:enterSubnet()
					   return true
				   end))

	self:tieAndShowWindow(window)
	return window
end


function enterSubnet(self)
	local v = Textinput.ipAddressValue(self.ipSubnet)

	local window = Window("window", self:string("NETWORK_SUBNET"))

	window:addWidget(Textarea("help", self:string("NETWORK_SUBNET_HELP")))
	window:addWidget(Textinput("textinput", v,
				   function(_, value)
					   value = value:getValue()

					   self.ipSubnet = value
					   self.ipGateway = _gateway(self)

					   self:enterGateway()
					   return true
				   end))

	self:tieAndShowWindow(window)
	return window
end


function enterGateway(self)
	local v = Textinput.ipAddressValue(self.ipGateway)

	local window = Window("window", self:string("NETWORK_GATEWAY"))

	window:addWidget(Textarea("help", self:string("NETWORK_GATEWAY_HELP")))
	window:addWidget(Textinput("textinput", v,
				   function(_, value)
					   value = value:getValue()

					   if not _validip(value) then
						   return false
					   end

					   self.ipGateway = value
					   self.ipDNS = self.ipGateway

					   self:enterDNS()
					   return true
				   end))

	self:tieAndShowWindow(window)
	return window
end


function enterDNS(self)
	local v = Textinput.ipAddressValue(self.ipDNS)

	local window = Window("window", self:string("NETWORK_DNS"))

	window:addWidget(Textarea("help", self:string("NETWORK_DNS_HELP")))
	window:addWidget(Textinput("textinput", v,
				   function(_, value)
					   value = value:getValue()

					   if not _validip(value) then
						   return false
					   end

					   self.ipDNS = value
					   self:setStaticIP()
					   return true
				   end))

	self:tieAndShowWindow(window)
	return window
end


function setStaticIP(self)
	log:warn("setStaticIP addr=", self.ipAddress, " subnet=", self.ipSubnet, " gw=", self.ipGateway, " dns=", self.ipDNS)

	jnt:perform(function()
			    self.t_ctrl:t_setStaticIP(self.ssid, self.ipAddress, self.ipSubnet, self.ipGateway, self.ipDNS)
			    jnt:t_perform(function()
						  connectOK(self)
					  end)
		    end)
end


function t_removeNetwork(self, ssid)
	self.t_ctrl:t_removeNetwork(ssid)

	-- Update state in main thread
	jnt:t_perform(function()
			      -- remove from menu
			      local item = self.scanResults[ssid].item
			      self.scanMenu:removeItem(item)

			      -- clear entry
			      self.scanResults[ssid] = nil
		      end)
end


function removeNetwork(self, ssid)
	-- forget the network
	jnt:perform(function()
			    self:t_removeNetwork(ssid)
		    end)

	-- popup confirmation
	local window = Popup("popupIcon")
	local text = Textarea("text", self:string("NETWORK_FORGOTTEN_NETWORK", ssid))
	window:addWidget(text)

	self:tieWindow(window)
	window:showBriefly(2000, function() _hideToTop(self) end)

	return window
end


function connectOrDelete(self, ssid)
	local window = Window("window", ssid)

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_CONNECT_TO_NETWORK"), nil,
						callback = function()
								   self.ssid = ssid
								   connect(self)
							   end
					},
					{
						text = self:string("NETWORK_FORGET_NETWORK"), nil,
						callback = function()
								   deleteConfirm(self, ssid)
							   end
					},
				})

	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


function deleteConfirm(self, ssid)
	local window = Window("window", self:string("NETWORK_FORGET_NETWORK"))

	local menu = SimpleMenu("menu",
				{
					{
						text = self:string("NETWORK_FORGET_CANCEL"), nil,
						callback = function()
								   window:hide()
							   end
					},
					{
						text = self:string("NETWORK_FORGET_CONFIRM", ssid), nil,
						callback = function()
								   removeNetwork(self, ssid)
							   end
					},
				})

	window:addWidget(Textarea("help", self:string("NETWORK_FORGET_HELP", ssid)))
	window:addWidget(menu)

	self:tieAndShowWindow(window)
	return window
end


local stateTxt = {
	[ "DISCONNECTED" ] = "NETWORK_STATE_DISCONNECTED",
	[ "INACTIVE" ] = "NETWORK_STATE_DISCONNECTED",
	[ "SCANNING" ] = "NETWORK_STATE_SCANNING",
	[ "ASSOCIATING" ] = "NETWORK_STATE_CONNECTING",
	[ "ASSOCIATED" ] = "NETWORK_STATE_CONNECTING",
	[ "4WAY_HANDSHAKE" ] = "NETWORK_STATE_HANDSHAKE",
	[ "GROUP_HANDSHAKE" ] = "NETWORK_STATE_HANDSHAKE",
	[ "COMPLETED" ] = "NETWORK_STATE_CONNECTED",
}


function t_networkStatusTimer(self, values)
	local status = self.t_ctrl:t_wpaStatusRequest()

	local snr = self.t_ctrl:getSNR()
	local rssi = self.t_ctrl:getRSSI()
	local nf = self.t_ctrl:getNF()

	local wpa_state = stateTxt[status.wpa_state] or "NETWORK_STATE_UNKNOWN"

	local encryption = status.key_mgmt
	-- white lie :)
	if string.match(status.pairwise_cipher, "WEP") then
		encryption = "WEP"
	end

	-- update the ui in the main thread
	jnt:t_perform(function()
			      values[1]:setValue(self:string(wpa_state))
			      values[2]:setValue(tostring(status.ssid))
			      values[3]:setValue(tostring(status.bssid))
			      values[4]:setValue(tostring(encryption))
			      values[5]:setValue(tostring(status.ip_address))
			      values[6]:setValue(tostring(snr))
			      values[7]:setValue(tostring(rssi))
			      values[8]:setValue(tostring(nf))
		      end)
end


function networkStatusTimer(self, values)
	jnt:perform(function()
			    self:t_networkStatusTimer(values)
		    end)
end


function networkStatusShow(self)
	local window = Window("window", self:string("NETWORK_STATUS"))

	local values = {}
	for i=1,8 do
		values[i] = Label("value", "")
	end

	-- FIXME format this nicely
	local menu = SimpleMenu("menu",
				{
				   { text = self:string("NETWORK_STATE"), icon = values[1] },
				   { text = self:string("NETWORK_SSID"), icon = values[2] },
				   { text = self:string("NETWORK_BSSID"), icon = values[3] },
				   { text = self:string("NETWORK_ENCRYPTION"), icon = values[4] },
				   { text = self:string("NETWORK_IP_ADDRESS"), icon = values[5] },
				   { text = self:string("NETWORK_SNR"), icon = values[6] },
				   { text = self:string("NETWORK_RSSI"), icon = values[7] },
				   { text = self:string("NETWORK_NF"), icon = values[8] },
				})
	window:addWidget(menu)

	self:networkStatusTimer(values)
	window:addTimer(1000, function()
				      self:networkStatusTimer(values)
			      end)

	self:tieAndShowWindow(window)
	return window
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]
