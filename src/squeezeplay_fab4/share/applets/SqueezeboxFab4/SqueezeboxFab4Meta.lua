
local oo            = require("loop.simple")

local AppletMeta    = require("jive.AppletMeta")
local jul           = require("jive.utils.log")

local appletManager = appletManager
local jiveMain      = jiveMain


module(...)
oo.class(_M, AppletMeta)


function jiveVersion(meta)
	return 1, 1
end


function defaultSettings(meta)
	return { 
	}
end


function registerApplet(meta)
	jul.addCategory("squeezeboxFab4", jul.DEBUG)

	-- BSP is a resident Applet
	appletManager:loadApplet("SqueezeboxFab4")


	-- audio playback defaults
	appletManager:addDefaultSetting("Playback", "enableAudio", 1)

	appletManager:addDefaultSetting("Playback", "alsaPlaybackDevice", "default")
	appletManager:addDefaultSetting("Playback", "alsaPlaybackBufferTime", 30000)
	appletManager:addDefaultSetting("Playback", "alsaPlaybackPeriodCount", 3)
	appletManager:addDefaultSetting("Playback", "alsaEffectsDevice", "plughw:2,0")
	appletManager:addDefaultSetting("Playback", "alsaEffectsBufferTime", 30000)
	appletManager:addDefaultSetting("Playback", "alsaEffectsPeriodCount", 3)


	-- settings
	jiveMain:addItem(meta:menuItem('brightnessSetting', 'screenSettings', "BSP_BRIGHTNESS", function(applet, ...) applet:settingsBrightnessShow(...) end))


	-- services
	meta:registerService("getBrightness")
	meta:registerService("setBrightness")
end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

