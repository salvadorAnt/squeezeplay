
--[[
=head1 NAME

applets.QVGAlandscapeSkin.QVGAlandscapeSkinApplet - The skin for the Squeezebox Controller

=head1 DESCRIPTION

This applet implements the skin for the Squeezebox Controller

=head1 FUNCTIONS

Applet related methods are described in L<jive.Applet>.

=cut
--]]


-- stuff we use
local ipairs, pairs, setmetatable, type = ipairs, pairs, setmetatable, type

local oo                     = require("loop.simple")

local Applet                 = require("jive.Applet")
local Audio                  = require("jive.ui.Audio")
local Font                   = require("jive.ui.Font")
local Framework              = require("jive.ui.Framework")
local Icon                   = require("jive.ui.Icon")
local Label                  = require("jive.ui.Label")
local RadioButton            = require("jive.ui.RadioButton")
local RadioGroup             = require("jive.ui.RadioGroup")
local SimpleMenu             = require("jive.ui.SimpleMenu")
local Surface                = require("jive.ui.Surface")
local Textarea               = require("jive.ui.Textarea")
local Tile                   = require("jive.ui.Tile")
local Window                 = require("jive.ui.Window")

local table                  = require("jive.utils.table")
local debug                  = require("jive.utils.debug")
local autotable              = require("jive.utils.autotable")

local QVGAbaseSkinApplet     = require("applets.QVGAbaseSkin.QVGAbaseSkinApplet")

local LAYER_FRAME            = jive.ui.LAYER_FRAME
local LAYER_CONTENT_ON_STAGE = jive.ui.LAYER_CONTENT_ON_STAGE

local LAYOUT_NORTH           = jive.ui.LAYOUT_NORTH
local LAYOUT_EAST            = jive.ui.LAYOUT_EAST
local LAYOUT_SOUTH           = jive.ui.LAYOUT_SOUTH
local LAYOUT_WEST            = jive.ui.LAYOUT_WEST
local LAYOUT_CENTER          = jive.ui.LAYOUT_CENTER
local LAYOUT_NONE            = jive.ui.LAYOUT_NONE

local WH_FILL                = jive.ui.WH_FILL

local jiveMain               = jiveMain
local appletManager          = appletManager


module(..., Framework.constants)
oo.class(_M, QVGAbaseSkinApplet)


function init(self)
	self.images = {}
end


function param(self)
	return {
		THUMB_SIZE = 56,
		NOWPLAYING_MENU = true,
		nowPlayingBrowseArtworkSize = 154,
		nowPlayingSSArtworkSize     = 186,
		nowPlayingLargeArtworkSize  = 240,
        }
end

-- skin
-- The meta arranges for this to be called to skin Jive.
function skin(self, s, reload, useDefaultSize)
	

	local screenWidth, screenHeight = Framework:getScreenSize()

	if useDefaultSize or screenWidth < 320 or screenHeight < 240 then
                screenWidth = 320
                screenHeight = 240
        end

        Framework:setVideoMode(screenWidth, screenHeight, 16, jiveMain:isFullscreen())

	--init lastInputType so selected item style is not shown on skin load
	Framework.mostRecentInputType = "scroll"

	-- almost all styles come directly from QVGAbaseSkinApplet
	QVGAbaseSkinApplet.skin(self, s, reload, useDefaultSize)

	-- styles specific to the landscape QVGA skin

	local NP_ARTISTALBUM_FONT_SIZE = 16
	local NP_TRACK_FONT_SIZE = 16

	-- Artwork
	local ARTWORK_SIZE    = self:param().nowPlayingBrowseArtworkSize

	local controlHeight   = 38
	local controlWidth    = 45
	local volumeBarWidth  = 150
	local buttonPadding   = 0
	local NP_TITLE_HEIGHT = 31

	local _tracklayout = {
		border = { 4, 0, 4, 0 },
		position = LAYOUT_NORTH,
		w = WH_FILL,
		align = "left",
		lineHeight = NP_TRACK_FONT_SIZE,
		fg = { 0xe7, 0xe7, 0xe7 },
	}

	s.nowplaying = _uses(s.window, {
		-- Song metadata
		nptrack =  {
			border     = _tracklayout.border,
			position   = _tracklayout.position,
			w          = _tracklayout.w,
			align      = _tracklayout.align,
			lineHeight = _tracklayout.lineHeight,
			fg         = _tracklayout.fg,
			padding    = { ARTWORK_SIZE + 10, NP_TITLE_HEIGHT + 15, 20, 10 },
			font       = _boldfont(NP_TRACK_FONT_SIZE), 
		},
		npartist  = {
			border     = _tracklayout.border,
			position   = _tracklayout.position,
			w          = _tracklayout.w,
			align      = _tracklayout.align,
			lineHeight = _tracklayout.lineHeight,
			fg         = _tracklayout.fg,
			padding    = { ARTWORK_SIZE + 10, NP_TITLE_HEIGHT + 45, 20, 10 },
			font       = _font(NP_ARTISTALBUM_FONT_SIZE),
		},
		npalbum = {
			border     = _tracklayout.border,
			position   = _tracklayout.position,
			w          = _tracklayout.w,
			align      = _tracklayout.align,
			lineHeight = _tracklayout.lineHeight,
			fg         = _tracklayout.fg,
			padding    = { ARTWORK_SIZE + 10, NP_TITLE_HEIGHT + 75, 20, 10 },
			font       = _font(NP_ARTISTALBUM_FONT_SIZE),
		},
	
		-- cover art
		npartwork = {
			w = ARTWORK_SIZE,
			border = { 8, NP_TITLE_HEIGHT + 6, 10, 0 },
			position = LAYOUT_WEST,
			align = "center",
			artwork = {
				align = "center",
				padding = 0,
				-- FIXME: this is a placeholder
				img = _loadImage(self, "UNOFFICIAL/icon_album_noartwork_190.png"),
			},
		},
	
		--transport controls
		npcontrols = { hidden = 1 },
	
		-- Progress bar
		npprogress = {
			position = LAYOUT_NONE,
			x = 4,
			y = NP_TITLE_HEIGHT + ARTWORK_SIZE + 2,
			padding = { 0, 10, 0, 0 },
			order = { "elapsed", "slider", "remain" },
			elapsed = {
				w = 50,
				align = 'right',
				padding = { 4, 0, 6, 10 },
				font = _boldfont(10),
				fg = { 0xe7,0xe7, 0xe7 },
				sh = { 0x37, 0x37, 0x37 },
			},
			remain = {
				w = 50,
				align = 'left',
				padding = { 6, 0, 4, 10 },
				font = _boldfont(10),
				fg = { 0xe7,0xe7, 0xe7 },
				sh = { 0x37, 0x37, 0x37 },
			},
		},
	
		-- special style for when there shouldn't be a progress bar (e.g., internet radio streams)
		npprogressNB = {
			position = LAYOUT_NONE,
			x = 8,
			y = NP_TITLE_HEIGHT + ARTWORK_SIZE + 2,
			padding = { ARTWORK_SIZE + 22, 0, 0, 5 },
			order = { "elapsed" },
			elapsed = {
				w = WH_FILL,
				align = "left",
				padding = { 0, 0, 0, 5 },
				font = _boldfont(10),
				fg = { 0xe7, 0xe7, 0xe7 },
				sh = { 0x37, 0x37, 0x37 },
			},
		},
	
	})

	-- sliders
	-- FIXME: I'd much rather describe slider style within the s.nowplaying window table above, otherwise describing alternative window styles for NP will be problematic
	s.npprogressB = {
		w = screenWidth - 120,
		h = 25,
		padding     = { 0, 0, 0, 5 },
                position = LAYOUT_SOUTH,
                horizontal = 1,
                bgImg = s.sliderBackground,
                img = s.sliderBar,
	}

	s.npvolumeB = { hidden = 1 }
	s.nowplayingSS = _uses(s.nowplaying)

end


--[[

=head1 LICENSE

Copyright 2007 Logitech. All Rights Reserved.

This file is subject to the Logitech Public Source License Version 1.0. Please see the LICENCE file for details.

=cut
--]]

