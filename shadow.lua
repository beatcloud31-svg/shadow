local VERSION = "1.1.0"

local CONFIG = {
	Credits   = "X4V",
	Discord   = "https://discord.gg/EXrwmjYcU",

	-- Shown on the Home page. Edit names/roles here.
	Developers = {
		{ name = "X4V",      role = "UI Designer | Founder", avatar = "https://cdn.discordapp.com/avatars/1149740153850581054/21ea19ca39c74ff76502e2c3169985dd.png?size=128" },
	},

	-- Quick access scripts on the Home page: { name, desc, icon, url }
	QuickScripts = {
		{ name = "Infinite Yield", desc = "Admin commands", icon = "terminal", url = "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source" },
	},
	ToggleKey = Enum.KeyCode.RightShift,
	NotifyPosition = "TopRight",

	Key = {
		Enabled     = true,
		GetKeyLink  = "https://direct-link.net/10467882/1BXMAi69pzfM",

		RemoteUrl   = "",
		Keys        = {},  -- plain keys (optional): "KEY | YYYY-MM-DD". Empty = only bot-generated keys work.
		-- keys from /shadowgenkey (SF-... lifetime, ST-... timed). Must match
		-- shadow_secret in the bot's config.json, or generated keys won't work.
		Secret      = "shadow-5353v4e7tbdjo01rcy0725s9xj",
		DefaultDays = 30,    -- keys with no date expire this many days after first use (0 = never)
		Remember    = true,
		OfflineHours = 48,   -- how long the last downloaded key list stays usable if the server is down
		MaxAttempts = 5,
		LockSeconds = 30,
	},
}

local SCRIPTS = {}

local CHANGELOG = {
	{
		version = "1.1.0", date = "2026-10-31", title = "Home page and polish",
		changes = {
			{ "new", "Home page with your avatar, latest update, quick-access scripts and credits" },
			{ "new", "Top tab bar: hold the toggle button and slide to a tab" },
			{ "improved", "Notifications: accent strip, pulse ring, springy slide-in and error shake" },
			{ "improved", "Key system shows expiry, remembers lockouts and handles server errors" },
			{ "new", "Signed keys from the Discord bot (SF- lifetime, ST- timed) work offline" },
			{ "removed", "Title glitch effect" },
		},
	},
	{
		version = "1.0.0", date = "2026-10-27", title = "Initial release",
		changes = {
			{ "new", "Key system in its own window, with saved keys and optional key expiry" },
			{ "new", "Editor: tabs, saved scripts, line numbers and Lua syntax colours" },
			{ "new", "ScriptBlox browser with search, filters and one-tap run / copy" },
			{ "new", "Themes (8 presets incl. Liquid Glass, plus custom), UI scale, corner radius and a full-screen glow" },
			{ "new", "Notifications, floating toggle button at the top with a hold-to-open tab bar, and Settings" },
			{ "new", "Optional Console tab (Settings > Console) showing live Roblox output" },
		},
	},
}

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")

if not game:IsLoaded() then game.Loaded:Wait() end
do
	while not Players.LocalPlayer do task.wait() end
	local t0 = os.clock()
	while not workspace.CurrentCamera and os.clock() - t0 < 10 do task.wait() end
	task.wait(0.5)
end

local env = (getgenv and getgenv()) or _G
if env.ShadowLauncherUnload then pcall(env.ShadowLauncherUnload) end

local function getParent()
	if gethui then
		local ok, h = pcall(gethui)
		if ok and h then return h end
	end
	local ok, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok and cg then return cg end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

local parentGui = getParent()
for _, g in ipairs(parentGui:GetChildren()) do
	if g.Name == "ShadowLauncher" then g:Destroy() end
end

local G2L = {}
local g2lCount = 0
local function G2L_register(o, name)
	g2lCount = g2lCount + 1
	G2L[tostring(g2lCount)] = o
	if name then G2L[name] = o end
	return o
end

local gui = Instance.new("ScreenGui")
gui.Name = "ShadowLauncher"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = parentGui

local GuiService = game:GetService("GuiService")
local function readTopInset()
	local h = 0
	local ok, r = pcall(function() return GuiService.TopbarInset end)
	if ok and r then h = r.Max.Y end
	if h <= 0 then
		local ok2, v = pcall(function() return GuiService:GetGuiInset().Y end)
		if ok2 and v then h = v end
	end
	return math.clamp(math.floor(h), 0, 90)
end
local TOP_INSET = readTopInset()
G2L_register(gui, "ScreenGui")

local STATE = { revealed = not CONFIG.Key.Enabled, dragTargets = {}, glassHooks = {} }

local alive = true
local conns = {}
local function bind(sig, fn)
	local c = sig:Connect(fn)
	conns[#conns + 1] = c
	return c
end
local function cleanup()
	if not alive then return end
	alive = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	pcall(function() gui:Destroy() end)
	if STATE.keyGui then pcall(function() STATE.keyGui:Destroy() end) end
	for k in pairs(G2L) do G2L[k] = nil end
	if env.ShadowLauncherUnload == cleanup then env.ShadowLauncherUnload = nil end
end
env.ShadowLauncherUnload = cleanup

local function trim(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local FOLDER = "ShadowLauncher"
local function canFile()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end
local function fileRead(name)
	if not canFile() then return nil end
	local ok, r = pcall(function()
		if isfile(FOLDER .. "/" .. name) then return readfile(FOLDER .. "/" .. name) end
	end)
	if ok and r then return trim(r) end
	return nil
end
local function fileWrite(name, data)
	if not canFile() then return end
	pcall(function()
		if isfolder and makefolder and not isfolder(FOLDER) then makefolder(FOLDER) end
		writefile(FOLDER .. "/" .. name, data)
	end)
end

local SETTINGS = {
	Notifications  = true,
	NotifyPosition = CONFIG.NotifyPosition or "TopRight",
	NotifyDuration = "Normal",
	FloatButton    = true,
	Theme          = "Amethyst",
	CustomHue      = 210,
	CustomSat      = 1.0,
	CustomVal      = 1.0,
	UIScale        = 1,
	CornerRadius   = 16,
	WindowBorders  = true,
	ScreenGlow     = true,
	Console        = false,
	ToggleKey      = CONFIG.ToggleKey.Name,
	RememberKey    = CONFIG.Key.Remember,
}
do
	local raw = fileRead("settings.json")
	if raw and raw ~= "" then
		local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and type(data) == "table" then
			for k, v in pairs(SETTINGS) do
				if type(data[k]) == type(v) then SETTINGS[k] = data[k] end
			end
		end
	end
end
local toggleKey = CONFIG.ToggleKey
do
	local ok, kc = pcall(function() return Enum.KeyCode[SETTINGS.ToggleKey] end)
	if ok and kc then toggleKey = kc end
end
CONFIG.Key.Remember = SETTINGS.RememberKey
local rebinding = false
local floatApply

local function saveSettings()
	fileWrite("settings.json", HttpService:JSONEncode(SETTINGS))
end

local BASE_HUE = 357
local THEMES = {
	{ name = "Amethyst", hue = 262, sat = 0.95, val = 1 },
	{ name = "Liquid Glass", hue = 208, sat = 0.5, val = 1, glass = true },
	{ name = "Shadow",  hue = 357, sat = 1.00, val = 1 },
	{ name = "Ocean",   hue = 205, sat = 1.00, val = 1 },
	{ name = "Emerald", hue = 150, sat = 0.95, val = 1 },
	{ name = "Violet",  hue = 268, sat = 1.00, val = 1 },
	{ name = "Sunset",  hue = 22,  sat = 1.00, val = 1 },
	{ name = "Rose",    hue = 328, sat = 0.85, val = 1 },
	{ name = "Mono",    hue = 357, sat = 0.10, val = 1 },
}

local function themeParams(name)
	if name == "Custom" then
		return {
			hue = SETTINGS.CustomHue - BASE_HUE,
			sat = math.clamp(SETTINGS.CustomSat, 0.2, 1),
			val = math.clamp(SETTINGS.CustomVal, 0.6, 1),
		}
	end
	for _, t in ipairs(THEMES) do
		if t.name == name then return { hue = t.hue - BASE_HUE, sat = t.sat, val = t.val, glass = t.glass } end
	end
	return { hue = 0, sat = 1, val = 1 }
end
local TH = themeParams(SETTINGS.Theme)
STATE.glass = TH.glass or false

local function xform(c, th)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV((h + th.hue / 360) % 1, math.clamp(s * th.sat, 0, 1), math.clamp(v * th.val, 0, 1))
end
local function unxform(c, th)
	local h, s, v = c:ToHSV()
	return Color3.fromHSV((h - th.hue / 360) % 1, math.clamp(s / th.sat, 0, 1), math.clamp(v / th.val, 0, 1))
end
local function cdist(a, b)
	local dr, dg, db = (a.R - b.R) * 255, (a.G - b.G) * 255, (a.B - b.B) * 255
	return math.sqrt(dr * dr + dg * dg + db * db)
end

local BASE_LIST, BASE_SEEN = {}, {}
local function P(r, g, b)
	local base = Color3.fromRGB(r, g, b)
	local k = r * 65536 + g * 256 + b
	if not BASE_SEEN[k] then
		BASE_SEEN[k] = true
		BASE_LIST[#BASE_LIST + 1] = base
	end
	return xform(base, TH)
end

local C = {
	green   = Color3.fromRGB(90, 210, 125),
	amber   = Color3.fromRGB(255, 190, 70),
	blue    = Color3.fromRGB(90, 160, 255),
	blurple = Color3.fromRGB(88, 101, 242),
	white   = Color3.new(1, 1, 1),
}
local FIXED = { C.green, C.amber, C.blue, C.blurple, C.white, Color3.fromRGB(110, 124, 255), Color3.fromRGB(70, 80, 210) }

local THEME_KEYS = {
	bg = { 14, 12, 16 }, bg2 = { 22, 18, 24 }, side = { 17, 13, 18 }, card = { 30, 22, 28 }, stroke = { 80, 30, 40 },
	red = { 255, 50, 60 }, redHi = { 255, 70, 80 }, red2 = { 150, 0, 28 }, text = { 240, 232, 236 }, sub = { 160, 140, 150 },
}
local function refreshPalette()
	for k, rgb in pairs(THEME_KEYS) do C[k] = P(rgb[1], rgb[2], rgb[3]) end
end
refreshPalette()

local noThemeList, themeHooks = {}, {}
local function NoTheme(inst)
	noThemeList[#noThemeList + 1] = inst
	return inst
end

local function isSurface(c)
	return cdist(c, C.bg) < 2 or cdist(c, C.bg2) < 2 or cdist(c, C.card) < 2 or cdist(c, C.side) < 2
end
local function applyGlass()
	local on = STATE.glass
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("Frame") or d:IsA("CanvasGroup") or d:IsA("TextButton") then
			local t0 = d:GetAttribute("T0")
			if on then
				if t0 == nil and d.BackgroundTransparency < 0.95 and isSurface(d.BackgroundColor3) then
					d:SetAttribute("T0", d.BackgroundTransparency)
					d.BackgroundTransparency = d.BackgroundTransparency + (1 - d.BackgroundTransparency) * 0.55
				end
			elseif t0 ~= nil then
				d.BackgroundTransparency = t0
				d:SetAttribute("T0", nil)
			end
		end
	end
	for _, h in ipairs(STATE.glassHooks) do pcall(h, on) end
end

local function applyTheme(np)
	local old = { hue = TH.hue, sat = TH.sat, val = TH.val }
	local skip = {}
	for i = #noThemeList, 1, -1 do
		local r = noThemeList[i]
		if r.Parent then
			skip[r] = true
			for _, x in ipairs(r:GetDescendants()) do skip[x] = true end
		else
			table.remove(noThemeList, i)
		end
	end
	local function remap(c)
		for _, f in ipairs(FIXED) do
			if cdist(c, f) < 3 then return nil end
		end
		local cand = unxform(c, old)
		local best, bd
		for _, b in ipairs(BASE_LIST) do
			local d = cdist(cand, b)
			if not bd or d < bd then best, bd = b, d end
		end
		if best and bd < 7 then return xform(best, np) end
		return nil
	end
	local function setProp(o, prop)
		local n = remap(o[prop])
		if n then o[prop] = n end
	end

	for _, d in ipairs(gui:GetDescendants()) do
		if not skip[d] then
			if d:IsA("GuiObject") then setProp(d, "BackgroundColor3") end
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then setProp(d, "TextColor3") end
			if d:IsA("TextBox") then setProp(d, "PlaceholderColor3") end
			if d:IsA("ImageLabel") or d:IsA("ImageButton") then setProp(d, "ImageColor3") end
			if d:IsA("ScrollingFrame") then setProp(d, "ScrollBarImageColor3") end
			if d:IsA("UIStroke") then setProp(d, "Color") end
			if d:IsA("UIGradient") then
				local newk, changed = {}, false
				for i, kp in ipairs(d.Color.Keypoints) do
					local n = remap(kp.Value)
					if n then changed = true end
					newk[i] = ColorSequenceKeypoint.new(kp.Time, n or kp.Value)
				end
				if changed then d.Color = ColorSequence.new(newk) end
			end
			for k, v in pairs(d:GetAttributes()) do
				if typeof(v) == "Color3" then
					local n = remap(v)
					if n then d:SetAttribute(k, n) end
				end
			end
		end
	end

	TH.hue, TH.sat, TH.val = np.hue, np.sat, np.val
	refreshPalette()
	TH.glass = np.glass
	STATE.glass = np.glass or false
	applyGlass()
	for _, h in ipairs(themeHooks) do pcall(h) end
end

local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if STATE.glass and props and props.BackgroundColor3 and (class == "Frame" or class == "CanvasGroup" or class == "TextButton") then
		local bt = o.BackgroundTransparency
		if bt < 0.95 and isSurface(props.BackgroundColor3) then
			o:SetAttribute("T0", bt)
			o.BackgroundTransparency = bt + (1 - bt) * 0.55
		end
	end
	if parent then o.Parent = parent end
	return G2L_register(o, props and props.Name and props.Name ~= "" and ("n_" .. g2lCount + 1 .. "_" .. props.Name) or nil)
end

local function frame(props, parent)
	props.BorderSizePixel = 0
	return make("Frame", props, parent)
end

local function label(props, parent)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.Font = props.Font or Enum.Font.Gotham
	props.TextSize = props.TextSize or 12
	props.TextColor3 = props.TextColor3 or C.text
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	return make("TextLabel", props, parent)
end

local function round(o, r)
	return make("UICorner", { CornerRadius = UDim.new(0, r) }, o)
end

local function stroke(o, color, thickness, transparency)
	return make("UIStroke", {
		Color = color or C.stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, o)
end

local function gradient(o, c1, c2, rot)
	return make("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rot or 90 }, o)
end

local function tween(o, t, props, style, dir)
	local tw = TS:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function fmtNum(n)
	n = tonumber(n) or 0
	if n >= 1000000 then return string.format("%.1fM", n / 1000000) end
	if n >= 1000 then return string.format("%.1fK", n / 1000) end
	return tostring(math.floor(n))
end

local function esc(s)
	s = tostring(s or "")
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return s
end

local spinners = {}
local function spin(img) spinners[img] = true end
local function unspin(img)
	spinners[img] = nil
	if img and img.Parent then img.Rotation = 0 end
end

local Lucide
do
	local ok, lib = pcall(function()
		return loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/lucide-roblox-direct/refs/heads/main/source.lua"))()
	end)
	if ok and type(lib) == "table" and lib.GetAsset then Lucide = lib end
end

local GLYPH = {
	["x"] = "X", ["minus"] = "-", ["check"] = "v", ["circle-check"] = "v", ["circle-x"] = "x",
	["triangle-alert"] = "!", ["info"] = "i", ["play"] = ">", ["search"] = "?", ["lock"] = "#",
}

local ICON_ALIASES = {
	["trash-2"] = { "trash" }, ["circle-check"] = { "check-circle" }, ["circle-x"] = { "x-circle" },
	["triangle-alert"] = { "alert-triangle" }, ["circle-alert"] = { "alert-circle" }, ["loader-circle"] = { "loader-2", "loader" },
	["house"] = { "home" }, ["circle-plus"] = { "plus-circle" }, ["panel-left"] = { "sidebar" }, ["layout-grid"] = { "grid" },
	["search-x"] = { "search" }, ["badge-check"] = { "check-circle", "check" }, ["file-code"] = { "file-text", "file" },
	["shield-check"] = { "shield" }, ["bell-ring"] = { "bell" }, ["layout-dashboard"] = { "layout" }, ["square-dashed"] = { "square" },
	["circle-dot"] = { "circle" }, ["arrow-up-left"] = { "arrow-up" }, ["arrow-up-right"] = { "arrow-up" },
	["arrow-down-left"] = { "arrow-down" }, ["arrow-down-right"] = { "arrow-down" }, ["log-out"] = { "x" },
	["external-link"] = { "link" }, ["scan"] = { "maximize" }, ["keyboard"] = { "command" }, ["arrow-right"] = { "chevron-right" },
}
local function getAsset(n)
	if not Lucide then return nil end
	local ok, r = pcall(Lucide.GetAsset, n)
	if ok and r and r.Url then return r end
	return nil
end

local function setIcon(img, name)
	local a = getAsset(name)
	if not a and ICON_ALIASES[name] then
		for _, alt in ipairs(ICON_ALIASES[name]) do
			a = getAsset(alt)
			if a then break end
		end
	end
	local glyph = img:FindFirstChild("Glyph")
	if a and a.Url then
		img.Image = a.Url
		img.ImageRectSize = a.ImageRectSize
		img.ImageRectOffset = a.ImageRectOffset
		if glyph then glyph:Destroy() end
	else
		img.Image = ""
		if not glyph then
			glyph = make("TextLabel", {
				Name = "Glyph", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = img.ImageColor3,
			}, img)
		end
		glyph.Text = GLYPH[name] or "*"
	end
end

local function tintIcon(img, color)
	img.ImageColor3 = color
	local g = img:FindFirstChild("Glyph")
	if g then g.TextColor3 = color end
end

local function Icon(parent, name, px, color)
	local img = make("ImageLabel", {
		Name = "Icon", BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromOffset(px, px), ImageColor3 = color or C.white,
		ScaleType = Enum.ScaleType.Fit,
	}, parent)
	setIcon(img, name)
	return img
end

local NOTIF_W = 300
local NPOS = {
	TopRight    = { anchor = Vector2.new(1, 0), pos = UDim2.new(1, -14, 0, 14 + TOP_INSET),  slide = 1,  bottom = false },
	TopLeft     = { anchor = Vector2.new(0, 0), pos = UDim2.new(0, 14, 0, 14 + TOP_INSET),   slide = -1, bottom = false },
	BottomRight = { anchor = Vector2.new(1, 1), pos = UDim2.new(1, -14, 1, -14), slide = 1,  bottom = true },
	BottomLeft  = { anchor = Vector2.new(0, 1), pos = UDim2.new(0, 14, 1, -14),  slide = -1, bottom = true },
}
local DUR_SCALE = { Short = 0.6, Normal = 1, Long = 1.8 }
local npos = NPOS[SETTINGS.NotifyPosition] or NPOS.TopRight
local slideX = npos.slide * (NOTIF_W + 24)

local notifHolder = make("Frame", {
	Name = "Notifications", AnchorPoint = npos.anchor, Position = npos.pos,
	Size = UDim2.fromOffset(NOTIF_W, 520), BackgroundTransparency = 1, ZIndex = 100,
}, gui)
local notifLayout = make("UIListLayout", {
	SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8),
	HorizontalAlignment = npos.slide == 1 and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left,
	VerticalAlignment = npos.bottom and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top,
}, notifHolder)

local function applyNotifPosition(name)
	npos = NPOS[name] or NPOS.TopRight
	slideX = npos.slide * (NOTIF_W + 24)
	notifHolder.AnchorPoint = npos.anchor
	notifHolder.Position = npos.pos
	notifLayout.HorizontalAlignment = npos.slide == 1 and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
	notifLayout.VerticalAlignment = npos.bottom and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
end

local NOTIF_TYPES = {
	success = { icon = "circle-check", color = C.green },
	error   = { icon = "circle-x", color = C.red },
	warn    = { icon = "triangle-alert", color = C.amber },
	info    = { icon = "info", color = C.blue },
}
local notifOrder, activeToasts, liveToasts = 0, {}, {}
local MAX_TOASTS = 5

local function Notify(opts)
	if not alive then return end
	opts = opts or {}
	if SETTINGS.Notifications == false and not opts.Force then return end
	local kind = NOTIF_TYPES[opts.Type or "info"] or NOTIF_TYPES.info
	local dur = (opts.Duration or 4) * (DUR_SCALE[SETTINGS.NotifyDuration] or 1)
	local title, text = tostring(opts.Title or "Notice"), tostring(opts.Text or "")
	local dedupeKey = (opts.Type or "info") .. "|" .. title .. "|" .. text

	local live = liveToasts[dedupeKey]
	if live and not live.closed() then
		live.bump()
		return
	end

	notifOrder = notifOrder + 1
	local firstKey = g2lCount + 1

	local TEXT_X = 62
	local textW = NOTIF_W - TEXT_X - 16
	local textH = 0
	if text ~= "" then
		local okSize, sz = pcall(function()
			return TextService:GetTextSize(text, 12, Enum.Font.Gotham, Vector2.new(textW, 1000))
		end)
		textH = okSize and sz.Y or 15
	end
	local height = math.clamp(12 + 18 + (textH > 0 and (4 + textH) or 0) + 24, 60, 140)

	local holder = frame({ Name = "Toast", Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, LayoutOrder = notifOrder }, notifHolder)

	local halo = make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 44, 1, 44),
		BackgroundTransparency = 1, BorderSizePixel = 0, Image = "rbxassetid://5554236805", ImageColor3 = kind.color,
		ImageTransparency = 1, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(23, 23, 277, 277), SliceScale = 0.8, ZIndex = 0,
	}, holder)

	local card = make("CanvasGroup", {
		Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(slideX, 0), BackgroundColor3 = C.bg2,
		BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 1,
	}, holder)
	round(card, 14)
	local cardScale = make("UIScale", { Scale = 0.9 }, card)
	local cardStroke = stroke(card, kind.color, 1.2, 0.6)

	local bg = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = STATE.glass and 0.45 or 0, ZIndex = 0 }, card)
	gradient(bg, P(38, 30, 36), P(18, 14, 20), 90)
	local glow = frame({ Size = UDim2.new(0, 170, 1, 0), BackgroundColor3 = kind.color, ZIndex = 0 }, card)
	make("UIGradient", { Transparency = NumberSequence.new(0.72, 1), Rotation = 0 }, glow)
	frame({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 0, 1), BackgroundColor3 = C.white, BackgroundTransparency = 0.82, ZIndex = 1 }, card)
	local accent = frame({ Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = kind.color, ZIndex = 2 }, card)
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.55) }) }, accent)

	local sheen = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, ZIndex = 2 }, card)
	local sheenGrad = make("UIGradient", {
		Rotation = 20, Offset = Vector2.new(-1.3, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.82),
			NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
		}),
	}, sheen)

	local badge = frame({ Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(12, 11), BackgroundColor3 = kind.color, BackgroundTransparency = 0.8, ZIndex = 1 }, card)
	round(badge, 19)
	stroke(badge, kind.color, 1.2, 0.5)
	local badgeScale = make("UIScale", { Scale = 0 }, badge)
	local ring = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(38, 38), BackgroundTransparency = 1, ZIndex = 1 }, badge)
	round(ring, 40)
	local ringStroke = stroke(ring, kind.color, 2, 1)
	local ic = Icon(badge, opts.Icon or kind.icon, 19, kind.color)
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	ic.Rotation = -120

	label({
		Text = title, Font = Enum.Font.GothamBold, TextSize = 14, ZIndex = 1,
		Position = UDim2.fromOffset(TEXT_X, 10), Size = UDim2.new(1, -TEXT_X - 64, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd,
	}, card)
	if textH > 0 then
		label({
			Text = text, TextSize = 12, TextColor3 = P(176, 158, 168), TextWrapped = true, ZIndex = 1,
			TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(TEXT_X, 32), Size = UDim2.new(1, -TEXT_X - 16, 0, textH),
		}, card)
	end

	local counter = frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -34, 0, 11), Size = UDim2.fromOffset(26, 16), BackgroundColor3 = kind.color, BackgroundTransparency = 0.8, Visible = false, ZIndex = 1 }, card)
	round(counter, 8)
	local counterLbl = label({ Text = "x2", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = kind.color, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, counter)

	local closeIc = Icon(card, "x", 14, P(120, 104, 114))
	closeIc.AnchorPoint = Vector2.new(1, 0)
	closeIc.Position = UDim2.new(1, -12, 0, 12)

	local track = frame({ Position = UDim2.new(0, 14, 1, -11), Size = UDim2.new(1, -28, 0, 3), BackgroundColor3 = kind.color, BackgroundTransparency = 0.88, ZIndex = 1 }, card)
	round(track, 2)
	local bar = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = kind.color, ZIndex = 1 }, track)
	round(bar, 2)
	local head = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = C.white, ZIndex = 2 }, track)
	round(head, 4)
	stroke(head, kind.color, 2, 0.4)

	local k2 = g2lCount
	local closed, hovered, remaining, count = false, false, dur, 1

	local function dismiss()
		if closed then return end
		closed = true
		liveToasts[dedupeKey] = nil
		for i, h in ipairs(activeToasts) do
			if h == holder then table.remove(activeToasts, i) break end
		end
		if not card.Parent then return end
		tween(card, 0.3, { Position = UDim2.fromOffset(slideX, 0), GroupTransparency = 1 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(cardScale, 0.3, { Scale = 0.94 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tween(halo, 0.25, { ImageTransparency = 1 })
		task.delay(0.26, function()
			if holder.Parent then tween(holder, 0.22, { Size = UDim2.new(1, 0, 0, 0) }, Enum.EasingStyle.Quint) end
		end)
		task.delay(0.52, function()
			if holder.Parent then holder:Destroy() end
			for i = firstKey, k2 do G2L[tostring(i)] = nil end
		end)
	end

	local hit = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5 }, card)
	hit.MouseEnter:Connect(function()
		hovered = true
		tween(cardStroke, 0.15, { Transparency = 0.15 })
		tween(cardScale, 0.18, { Scale = 1.025 }, Enum.EasingStyle.Back)
		tintIcon(closeIc, C.white)
	end)
	hit.MouseLeave:Connect(function()
		hovered = false
		tween(cardStroke, 0.15, { Transparency = 0.6 })
		tween(cardScale, 0.18, { Scale = 1 })
		tintIcon(closeIc, P(120, 104, 114))
	end)
	hit.MouseButton1Click:Connect(function()
		if opts.Callback then task.spawn(opts.Callback) end
		dismiss()
	end)

	liveToasts[dedupeKey] = {
		closed = function() return closed end,
		bump = function()
			count = count + 1
			remaining = dur
			counter.Visible = true
			counterLbl.Text = "x" .. count
			counter.Size = UDim2.fromOffset(36, 22)
			tween(counter, 0.3, { Size = UDim2.fromOffset(26, 16) }, Enum.EasingStyle.Back)
			badgeScale.Scale = 0.7
			tween(badgeScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			cardScale.Scale = 1.06
			tween(cardScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			sheenGrad.Offset = Vector2.new(-1.3, 0)
			tween(sheenGrad, 0.7, { Offset = Vector2.new(1.3, 0) }, Enum.EasingStyle.Quad)
		end,
	}

	table.insert(activeToasts, holder)
	if #activeToasts > MAX_TOASTS then
		local oldest = table.remove(activeToasts, 1)
		if oldest and oldest.Parent then
			local c = oldest:FindFirstChildWhichIsA("CanvasGroup")
			if c then tween(c, 0.2, { GroupTransparency = 1 }) end
			task.delay(0.25, function() if oldest.Parent then oldest:Destroy() end end)
		end
	end

	tween(card, 0.6, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
	tween(card, 0.3, { GroupTransparency = 0 })
	tween(cardScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(0.2, function()
		if not ring.Parent then return end
		ringStroke.Transparency = 0.3
		tween(ring, 0.7, { Size = UDim2.fromOffset(62, 62) }, Enum.EasingStyle.Quint)
		tween(ringStroke, 0.7, { Transparency = 1 })
	end)
	if opts.Type == "error" then
		task.delay(0.55, function()
			for _, dx in ipairs({ -5, 5, -3, 3, 0 }) do
				if closed or not card.Parent then return end
				tween(card, 0.05, { Position = UDim2.fromOffset(dx, 0) })
				task.wait(0.05)
			end
		end)
	end
	tween(halo, 0.7, { ImageTransparency = 0.8 })
	task.delay(0.12, function()
		if not badge.Parent then return end
		tween(badgeScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(ic, 0.5, { Rotation = 0 }, Enum.EasingStyle.Back)
	end)
	task.delay(0.22, function()
		if sheen.Parent then tween(sheenGrad, 0.8, { Offset = Vector2.new(1.3, 0) }, Enum.EasingStyle.Quad) end
	end)
	task.spawn(function()
		while alive and not closed and remaining > 0 do
			local dt = task.wait()
			if not hovered then remaining = remaining - dt end
			local frac = math.clamp(remaining / dur, 0, 1)
			if bar.Parent then
				bar.Size = UDim2.new(frac, 0, 1, 0)
				head.Position = UDim2.new(frac, 0, 0.5, 0)
				if not closed and halo.ImageTransparency < 0.95 then halo.ImageTransparency = 0.8 + 0.05 * math.sin(os.clock() * 4) end
			end
		end
		dismiss()
	end)
end

local function httpGet(url)
	local ok, res = pcall(function() return game:HttpGet(url) end)
	if ok and type(res) == "string" and #res > 0 then return res end
	local req = (syn and syn.request) or (http and http.request) or http_request or request
	if req then
		local ok2, r = pcall(req, { Url = url, Method = "GET" })
		if ok2 and type(r) == "table" and type(r.Body) == "string" and #r.Body > 0
			and (r.StatusCode == nil or r.StatusCode < 400) then
			return r.Body
		end
	end
	return nil, ok and "Empty response" or tostring(res)
end

local function copyText(t)
	local f = setclipboard or toclipboard or (syn and syn.write_clipboard) or (Clipboard and Clipboard.set)
	if not f then return false end
	return (pcall(f, t))
end

local SB_API = "https://scriptblox.com/api/script"
local SB_RAW = "https://scriptblox.com/raw/"

local function runCode(src)
	local fn, err = loadstring(src)
	if not fn then return false, "Compile error: " .. tostring(err) end
	local ok, e = pcall(fn)
	if not ok then return false, tostring(e) end
	return true
end

local function fetchEntrySource(entry)
	local url = entry.url or (entry.slug and (SB_RAW .. entry.slug))
	if not url then return nil, "No url or slug set" end
	local src, err = httpGet(url)
	if not src then return nil, "Download failed: " .. tostring(err) end
	return src
end

local cam = workspace.CurrentCamera
local vp = (cam and cam.ViewportSize) or Vector2.new(1280, 720)

local MARGIN = 10
do
	local ag = gui.AbsoluteSize
	if ag.X > 100 and ag.Y > 100 then vp = ag end
end
local uiS0 = math.clamp(SETTINGS.UIScale, 1, 1.5)
local W = math.floor((vp.X - MARGIN * 2) / uiS0)
local H = math.floor((vp.Y - MARGIN * 2 - TOP_INSET) / uiS0)
local TOP_H, SIDE_W, STATUS_H = 0, 0, 0
local RAIL_W, RAIL_GAP = 58, 12
local WIN_W = W - RAIL_W - RAIL_GAP

local root = frame({
	Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, TOP_INSET / 2),
	Size = UDim2.new(1, -MARGIN * 2, 1, -MARGIN * 2 - TOP_INSET), BackgroundTransparency = 1, Visible = STATE.revealed,
}, gui)

local scaler = frame({ Name = "Scaler", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1 / uiS0, 1 / uiS0), BackgroundTransparency = 1 }, root)
local uiScale = make("UIScale", { Scale = uiS0 }, scaler)
local function applyUIScale(notify, instant)
	local eff = math.clamp(SETTINGS.UIScale, 1, 1.5)
	if instant then
		uiScale.Scale = eff
		scaler.Size = UDim2.fromScale(1 / eff, 1 / eff)
	else
		tween(uiScale, 0.3, { Scale = eff }, Enum.EasingStyle.Quint)
		tween(scaler, 0.3, { Size = UDim2.fromScale(1 / eff, 1 / eff) }, Enum.EasingStyle.Quint)
	end
end
applyUIScale(false, true)

local win = make("CanvasGroup", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -(RAIL_W + RAIL_GAP) / 2, 0.5, 0),
	Size = UDim2.new(1, -(RAIL_W + RAIL_GAP), 1, 0), BackgroundColor3 = C.bg, BackgroundTransparency = 1, BorderSizePixel = 0, GroupTransparency = 1,
}, scaler)
local winCorner = round(win, SETTINGS.CornerRadius)

local winBg = frame({ Name = "Bg", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 0.06, ZIndex = 0 }, win)
local winBgCorner = round(winBg, SETTINGS.CornerRadius)
gradient(winBg, P(26, 22, 28), P(12, 10, 14), 90)
local introScale = make("UIScale", { Scale = 0.88 }, win)
task.delay(1, function()
	if alive and STATE.revealed and win.Parent and win.GroupTransparency > 0.5 then
		tween(win, 0.3, { GroupTransparency = 0 })
		tween(introScale, 0.3, { Scale = 1 })
	end
end)

local border = frame({ Name = "Border", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 60, Interactable = false }, win)
local borderCorner = round(border, SETTINGS.CornerRadius)
local borderStroke = stroke(border, C.white, 1.25, 0.2)
local strokeGrad = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.red),
		ColorSequenceKeypoint.new(0.5, P(40, 10, 15)),
		ColorSequenceKeypoint.new(1, C.red),
	}),
}, borderStroke)
STATE.glassHooks[#STATE.glassHooks + 1] = function(on)
	winBg.BackgroundTransparency = on and 0.5 or 0.06
	borderStroke.Transparency = on and 0 or 0.2
	borderStroke.Thickness = on and 1.75 or 1.25
end
STATE.glassHooks[#STATE.glassHooks](STATE.glass)

local GLOW_PAD = 60
local backdrop = make("CanvasGroup", {
	Name = "Backdrop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, GLOW_PAD * 2, 1, GLOW_PAD * 2), BackgroundTransparency = 1, BorderSizePixel = 0,
	GroupTransparency = 1, ZIndex = 0,
}, scaler)
local function glowColors()
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, P(255, 120, 40)),
		ColorSequenceKeypoint.new(0.5, P(255, 60, 50)),
		ColorSequenceKeypoint.new(1, P(255, 160, 55)),
	})
end
local function glowImage(inset, sliceScale, transparency)
	return make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -inset * 2, 1, -inset * 2), BackgroundTransparency = 1, BorderSizePixel = 0,
		Image = "rbxassetid://5554236805", ImageColor3 = C.white, ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(23, 23, 277, 277), SliceScale = sliceScale,
	}, backdrop)
end
local halo = glowImage(0, 2.6, 0.56)
local haloGrad = make("UIGradient", { Color = glowColors(), Rotation = 45 }, halo)
local haloInner = glowImage(GLOW_PAD - 26, 1.1, 0.72)
local haloInnerGrad = make("UIGradient", { Color = glowColors(), Rotation = 225 }, haloInner)

do
	local plate = frame({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -(GLOW_PAD * 2 - 20), 1, -(GLOW_PAD * 2 - 20)), BackgroundColor3 = P(20, 14, 28), BackgroundTransparency = 0.18,
	}, backdrop)
	STATE.plateCorner = round(plate, SETTINGS.CornerRadius + 10)
	local tint = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white }, plate)
	STATE.tintCorner = round(tint, SETTINGS.CornerRadius + 10)
	make("UIGradient", {
		Color = glowColors(), Rotation = 45,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.84), NumberSequenceKeypoint.new(0.5, 0.94), NumberSequenceKeypoint.new(1, 0.84) }),
	}, tint)
	local ps = stroke(plate, C.white, 1.5, 0.35)
	STATE.plateGrad = make("UIGradient", {
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.redHi), ColorSequenceKeypoint.new(0.5, P(50, 12, 20)), ColorSequenceKeypoint.new(1, C.redHi) }),
	}, ps)
	STATE.glassHooks[#STATE.glassHooks + 1] = function(on) plate.BackgroundTransparency = on and 0.58 or 0.18 end
	STATE.glassHooks[#STATE.glassHooks](STATE.glass)
end

local function applyBorders()
	border.Visible = SETTINGS.WindowBorders
	backdrop.Visible = SETTINGS.WindowBorders
end
applyBorders()
task.delay(1, function()
	if alive and STATE.revealed and backdrop.Parent and backdrop.GroupTransparency > 0.5 then tween(backdrop, 0.5, { GroupTransparency = 0 }) end
end)

local screenBg, applyScreenGlow, recolorGlow
do
	screenBg = make("Frame", {
		Name = "ScreenGlow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ZIndex = 0, Interactable = false,
	}, gui)
	NoTheme(screenBg)
	local N = 12

	local keys = {}
	for i = 0, 8 do
		local k = i / 8
		keys[#keys + 1] = NumberSequenceKeypoint.new(k, math.clamp(1 - 0.8 * (1 - k) ^ 2.6, 0, 1))
	end
	local fade = NumberSequence.new(keys)

	local edges = { top = {}, right = {}, bottom = {}, left = {} }
	local function seg(list, i, anchor, pos, rot)
		local f = frame({ AnchorPoint = anchor, Position = pos, Size = UDim2.new(), BackgroundColor3 = C.white, BackgroundTransparency = 1, Interactable = false }, screenBg)
		make("UIGradient", { Transparency = fade, Rotation = rot }, f)
		list[i] = f
	end
	for i = 1, N do
		local x0 = (i - 1) / N
		seg(edges.top, i, Vector2.new(0, 0), UDim2.new(x0, 0, 0, 0), 90)
		seg(edges.bottom, i, Vector2.new(0, 1), UDim2.new(x0, 0, 1, 0), 270)
		seg(edges.left, i, Vector2.new(0, 0), UDim2.new(0, 0, x0, 0), 0)
		seg(edges.right, i, Vector2.new(1, 0), UDim2.new(1, 0, x0, 0), 180)
	end
	local function layout()
		local vs = gui.AbsoluteSize
		local T = math.floor(math.min(vs.X, vs.Y) * 0.3)
		for i = 1, N do
			edges.top[i].Size = UDim2.new(1 / N, 0, 0, T)
			edges.bottom[i].Size = UDim2.new(1 / N, 0, 0, T)
			edges.left[i].Size = UDim2.new(0, T, 1 / N, 0)
			edges.right[i].Size = UDim2.new(0, T, 1 / N, 0)
		end
	end
	layout()
	bind(gui:GetPropertyChangedSignal("AbsoluteSize"), layout)

	recolorGlow = function(phase)
		local stops = { P(255, 120, 40), P(255, 60, 50), P(255, 160, 55), P(255, 60, 50) }
		local function ring(u)
			local pos = ((u + phase) % 1) * #stops
			local i0 = math.floor(pos)
			return stops[i0 % #stops + 1]:Lerp(stops[(i0 + 1) % #stops + 1], pos - i0)
		end
		for i = 1, N do
			local m = (i - 0.5) / N
			edges.top[i].BackgroundColor3 = ring(m * 0.25)
			edges.right[i].BackgroundColor3 = ring(0.25 + m * 0.25)
			edges.bottom[i].BackgroundColor3 = ring(0.5 + (1 - m) * 0.25)
			edges.left[i].BackgroundColor3 = ring(0.75 + (1 - m) * 0.25)
		end
	end
	recolorGlow(0)

	applyScreenGlow = function() screenBg.Visible = SETTINGS.ScreenGlow end
	applyScreenGlow()

	STATE.glowShown = false
	STATE.fadeGlow = function(t, on)
		STATE.glowShown = on
		for _, list in pairs(edges) do
			for _, f in ipairs(list) do tween(f, t, { BackgroundTransparency = on and 0 or 1 }) end
		end
	end
	task.delay(1.5, function()
		if alive and screenBg.Parent and not STATE.glowShown and STATE.fadeGlow then STATE.fadeGlow(0.6, true) end
	end)
end

local topbar = frame({ Name = "TopBar", Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, ZIndex = 5, Visible = false }, win)
frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(34, 4), BackgroundColor3 = C.sub, BackgroundTransparency = 0.65 }, topbar)
round(topbar:FindFirstChildWhichIsA("Frame"), 2)

local logo = Icon(topbar, "ghost", 20, C.red)
logo.Position = UDim2.fromOffset(16, 6)
logo.Visible = false

local titleHolder = frame({ Position = UDim2.fromOffset(42, 0), Size = UDim2.fromOffset(78, TOP_H), BackgroundTransparency = 1 }, topbar)
titleHolder.Visible = false
local function makeTitle(color, z)
	return label({
		Text = "SHADOW", Font = Enum.Font.GothamBlack, TextSize = 17, TextColor3 = color,
		Size = UDim2.fromScale(1, 1), ZIndex = z,
	}, titleHolder)
end
local title = makeTitle(C.white, 2)
local titleStroke = stroke(title, C.red, 1.2, 0.5)
titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
local titleGrad = gradient(title, P(255, 80, 80), P(190, 0, 25), 90)

local pill = frame({ Position = UDim2.fromOffset(122, 7), Size = UDim2.fromOffset(46, 18), BackgroundColor3 = C.red, BackgroundTransparency = 0.8 }, topbar)
round(pill, 9)
pill.Visible = false
label({ Text = "v" .. VERSION, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.redHi, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center }, pill)

local function IconBtn(parent, name, px, props)
	props.BackgroundColor3 = props.BackgroundColor3 or C.card
	props.Text = ""
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local b = make("TextButton", props, parent)
	b:SetAttribute("Rest", props.BackgroundColor3)
	round(b, 8)
	local ic = Icon(b, name, px, C.sub)
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	bind(b.MouseEnter, function() tween(b, 0.15, { BackgroundColor3 = C.red2 }) tintIcon(ic, C.white) end)
	bind(b.MouseLeave, function() tween(b, 0.15, { BackgroundColor3 = b:GetAttribute("Rest") }) tintIcon(ic, C.sub) end)
	return b, ic
end

local side = frame({ Name = "Rail", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, RAIL_W, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, scaler)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center }, side)
local railPill = frame({ Name = "Pill", Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.bg2, LayoutOrder = 1 }, side)
local pillCorner = round(railPill, 18)
stroke(railPill, C.stroke, 1, 0.3)
make("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, railPill)
local tabList = frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, railPill)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, tabList)

local closeBtn = make("TextButton", { Name = "Hide", Size = UDim2.fromOffset(50, 50), BackgroundColor3 = C.white, Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = 2 }, side)
round(closeBtn, 25)
gradient(closeBtn, C.redHi, C.red2, 90)
stroke(closeBtn, C.redHi, 3, 0.55)
local closeScale = make("UIScale", {}, closeBtn)
local closeIc = Icon(closeBtn, "x", 22, C.white)
closeIc.AnchorPoint = Vector2.new(0.5, 0.5)
closeIc.Position = UDim2.fromScale(0.5, 0.5)
bind(closeBtn.MouseEnter, function() tween(closeScale, 0.15, { Scale = 1.07 }) end)
bind(closeBtn.MouseLeave, function() tween(closeScale, 0.15, { Scale = 1 }) end)
bind(closeBtn.MouseButton1Down, function() tween(closeScale, 0.08, { Scale = 0.93 }) end)
bind(closeBtn.MouseButton1Up, function() tween(closeScale, 0.15, { Scale = 1.07 }, Enum.EasingStyle.Back) end)

local function applyCorner(r)
	winCorner.CornerRadius = UDim.new(0, r)
	winBgCorner.CornerRadius = UDim.new(0, r)
	borderCorner.CornerRadius = UDim.new(0, r)
	pillCorner.CornerRadius = UDim.new(0, math.min(r + 2, 22))
	if STATE.plateCorner then STATE.plateCorner.CornerRadius = UDim.new(0, r + 10) end
	if STATE.tintCorner then STATE.tintCorner.CornerRadius = UDim.new(0, r + 10) end
end
applyCorner(SETTINGS.CornerRadius)

local content = frame({
	Name = "Content", Position = UDim2.fromOffset(SIDE_W, TOP_H),
	Size = UDim2.new(1, -SIDE_W, 1, -TOP_H - STATUS_H), BackgroundTransparency = 1, ClipsDescendants = true,
}, win)

local status = frame({ Position = UDim2.new(0, SIDE_W, 1, -STATUS_H), Size = UDim2.new(1, -SIDE_W, 0, STATUS_H), BackgroundColor3 = C.bg, BackgroundTransparency = 0.3, Visible = false }, win)
local creditsLbl = label({
	Text = "", RichText = true,
	TextSize = 11, TextColor3 = C.sub, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.5, 0, 1, 0),
}, status)
local function updateCredits()
	local a = C.redHi
	creditsLbl.Text = string.format('Made by <font color="rgb(%d,%d,%d)"><b>%s</b></font>',
		math.floor(a.R * 255 + 0.5), math.floor(a.G * 255 + 0.5), math.floor(a.B * 255 + 0.5), esc(CONFIG.Credits))
end
updateCredits()
themeHooks[#themeHooks + 1] = updateCredits
local hintLbl = label({
	Text = "", TextSize = 10, TextColor3 = P(110, 95, 104), TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -12, 1, 0),
}, status)
local function updateHint()
	hintLbl.Text = UIS.TouchEnabled and ("v" .. VERSION) or (toggleKey.Name .. " to hide  |  v" .. VERSION)
end
updateHint()

local function Btn(parent, o)
	local b = make("TextButton", {
		Name = o.Name or "Btn", Size = o.Size, Position = o.Position or UDim2.new(),
		AnchorPoint = o.AnchorPoint or Vector2.new(), BackgroundColor3 = C.white,
		Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = o.LayoutOrder or 0,
	}, parent)
	round(b, o.Radius or 8)
	local c1, c2 = C.redHi, C.red2
	if o.Style == "ghost" then
		c1, c2 = P(56, 38, 48), P(36, 26, 34)
	elseif o.Style == "blurple" then
		c1, c2 = Color3.fromRGB(110, 124, 255), Color3.fromRGB(70, 80, 210)
	end
	local g = gradient(b, c1, c2, 90)
	local sc = make("UIScale", {}, b)
	bind(b.MouseEnter, function() tween(sc, 0.15, { Scale = 1.04 }) end)
	bind(b.MouseLeave, function() tween(sc, 0.15, { Scale = 1 }) end)
	bind(b.MouseButton1Down, function() tween(sc, 0.08, { Scale = 0.95 }) end)
	bind(b.MouseButton1Up, function() tween(sc, 0.12, { Scale = 1.04 }, Enum.EasingStyle.Back) end)

	local inner = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, b)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 5),
	}, inner)
	local ico = Icon(inner, o.Icon or "play", o.IconSize or 14, C.white)
	ico.LayoutOrder = 1
	local txt = label({
		Text = o.Text or "", Font = Enum.Font.GothamBold, TextSize = o.TextSize or 12, TextColor3 = C.white,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2,
	}, inner)
	return { Button = b, Icon = ico, Label = txt, Gradient = g }
end

local function setBtn(btn, text, iconName)
	btn.Label.Text = text
	if iconName then setIcon(btn.Icon, iconName) end
end

local function Chip(parent, text, iconName, onChange)
	local on = false
	local b = make("TextButton", {
		Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, Text = "",
		AutoButtonColor = false, BackgroundColor3 = C.card, BorderSizePixel = 0,
	}, parent)
	round(b, 12)
	local st = stroke(b, C.stroke, 1, 0.4)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 10) }, b)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5),
	}, b)
	local ic = Icon(b, iconName, 12, C.sub)
	ic.LayoutOrder = 1
	local lb = label({ Text = text, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.sub, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2 }, b)
	local function paint()
		tween(b, 0.15, { BackgroundColor3 = on and P(70, 22, 32) or C.card })
		tween(st, 0.15, { Color = on and C.red or C.stroke, Transparency = on and 0.1 or 0.4 })
		tintIcon(ic, on and C.redHi or C.sub)
		lb.TextColor3 = on and C.text or C.sub
	end
	bind(b.MouseButton1Click, function()
		on = not on
		paint()
		if onChange then onChange(on) end
	end)
	return b, function() return on end
end

local function Card(parent, o)
	local card = frame({ Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = C.card, LayoutOrder = o.Order or 0 }, parent)
	round(card, 10)
	local st = stroke(card, C.stroke, 1, 0.4)
	bind(card.MouseEnter, function() tween(st, 0.15, { Transparency = 0.05 }) end)
	bind(card.MouseLeave, function() tween(st, 0.15, { Transparency = 0.4 }) end)

	local box = frame({ Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = C.bg }, card)
	round(box, 9)
	local ic = Icon(box, o.Icon or "zap", 18, o.IconColor or C.red)
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)

	local rightW = 10 + 80 + (o.Copy and 38 or 0)
	local nameW = UDim2.new(1, -(58 + rightW + 4), 0, 18)
	label({
		Text = o.Title, Font = Enum.Font.GothamBold, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(58, 11), Size = nameW,
	}, card)
	local sub = label({
		Text = o.Sub or "", RichText = true, TextSize = 11, TextColor3 = C.sub, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(58, 31), Size = UDim2.new(1, -(58 + rightW + 4), 0, 16),
	}, card)

	local run = Btn(card, { Text = "Load", Icon = "play", Size = UDim2.fromOffset(80, 32), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0) })

	if o.Copy then
		local cp = IconBtn(card, "copy", 16, { Size = UDim2.fromOffset(32, 32), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0.5, 0), BackgroundColor3 = C.bg })
		bind(cp.MouseButton1Click, function()
			local text = o.Copy()
			if text and copyText(text) then
				Notify({ Title = "Copied", Text = "Loadstring copied to clipboard", Type = "success", Duration = 2.5 })
			else
				Notify({ Title = "Can't copy", Text = "Your executor has no clipboard function", Type = "warn" })
			end
		end)
	end

	local busy = false
	bind(run.Button.MouseButton1Click, function()
		if busy then return end
		busy = true
		setBtn(run, "Running", "loader-circle")
		spin(run.Icon)
		sub.Text = "Fetching script..."
		sub.TextColor3 = C.sub

		local ok, err = o.Run()
		unspin(run.Icon)
		if not alive then return end
		task.wait(0.2)

		if ok then
			setBtn(run, "Loaded", "check")
			sub.Text = "Executed successfully"
			sub.TextColor3 = C.green
			Notify({ Title = "Executed", Text = o.Title, Type = "success", Duration = 3 })
		else
			setBtn(run, "Retry", "refresh-cw")
			sub.Text = "Failed (see notification)"
			sub.TextColor3 = C.red
			warn("[Shadow] " .. tostring(err))
			Notify({ Title = "Execution failed", Text = tostring(err):sub(1, 90), Type = "error", Duration = 6 })
		end
		task.delay(2.5, function()
			if not alive or not card.Parent then return end
			if ok then setBtn(run, "Load", "play") end
			sub.Text = o.Sub or ""
			sub.TextColor3 = C.sub
		end)
		busy = false
	end)
	return card
end

local function Header(parent, titleText, subText)
	label({ Text = titleText, Font = Enum.Font.GothamBold, TextSize = 20, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 24) }, parent)
	label({ Text = subText, TextSize = 11, TextColor3 = C.sub, Position = UDim2.fromOffset(16, 33), Size = UDim2.new(1, -32, 0, 14) }, parent)
end

local function List(parent, pos, size)
	local sf = make("ScrollingFrame", {
		Position = pos, Size = size, BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.red, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, sf)
	make("UIPadding", { PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4) }, sf)
	return sf
end

local pages, tabs, current = {}, {}, nil
local unlocked = false
local sbOnOpen
local unread = (fileRead("seen.txt") ~= VERSION)

local function setTabActive(t, active)
	tween(t.btn, 0.2, { BackgroundTransparency = active and 0 or 1 })
	tintIcon(t.icon, active and C.white or C.sub)
end

local function showPage(name)
	if not unlocked or current == name then return end
	current = name
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, t in pairs(tabs) do setTabActive(t, n == name) end
	local p = pages[name]
	p.Position = UDim2.fromOffset(0, 10)
	tween(p, 0.25, { Position = UDim2.fromOffset(0, 0) })
	if name == "Updates" then
		unread = false
		tabs.Updates.dot.Visible = false
		fileWrite("seen.txt", VERSION)
	end
	if name == "ScriptBlox" and sbOnOpen then sbOnOpen() end
end

local function Tab(name, iconName, order)
	local b = make("TextButton", {
		Name = name, Size = UDim2.fromOffset(44, 44), BackgroundColor3 = C.white, BackgroundTransparency = 1,
		Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = order,
	}, tabList)
	local tabCorner = round(b, 14)
	gradient(b, C.redHi, C.red2, 90)
	local ic = Icon(b, iconName, 20, C.sub)
	ic.AnchorPoint = Vector2.new(0.5, 0.5)
	ic.Position = UDim2.fromScale(0.5, 0.5)
	local ind = frame({ Size = UDim2.fromOffset(3, 18), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -8, 0.5, 0), BackgroundColor3 = C.red, BackgroundTransparency = 1 }, b)
	round(ind, 2)
	local dot = frame({ Size = UDim2.fromOffset(8, 8), Position = UDim2.new(1, -11, 0, 3), BackgroundColor3 = C.red, Visible = false }, b)
	round(dot, 4)
	local t = { btn = b, icon = ic, ind = ind, dot = dot, corner = tabCorner }
	tabs[name] = t
	bind(b.MouseButton1Click, function() showPage(name) end)
	bind(b.MouseEnter, function() if current ~= name then tween(b, 0.15, { BackgroundTransparency = 0.88 }) end end)
	bind(b.MouseLeave, function() if current ~= name then tween(b, 0.15, { BackgroundTransparency = 1 }) end end)
	return t
end

local function newPage(name)
	local p = frame({ Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, content)
	pages[name] = p
	return p
end

local function safeBuild(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		err = tostring(err)
		warn("[Shadow] " .. name .. " failed to build: " .. err)
		Notify({ Title = name .. " failed to load", Text = err:sub(1, 140), Type = "error", Duration = 15, Force = true, Callback = function() copyText(err) end })
		if name ~= "Key" and name ~= "Float" then
			local pg = pages[name] or newPage(name)
			label({
				Text = "This tab failed to load:\n" .. err, TextWrapped = true, TextColor3 = C.red, TextSize = 12,
				TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(16, 16), Size = UDim2.new(1, -32, 1, -32),
			}, pg)
		end
	end
	return ok
end

do
local railTabLayout = tabList:FindFirstChildOfClass("UIListLayout")
local railLayout = side:FindFirstChildOfClass("UIListLayout")
local closeCorner = closeBtn:FindFirstChildOfClass("UICorner")
local function fitRail()
	local eff = math.clamp(SETTINGS.UIScale, 1, 1.5)
	local availH = root.AbsoluteSize.Y / eff
	if availH < 50 then return end
	local n = 0
	for _, t in pairs(tabs) do
		if t.btn.Visible then n = n + 1 end
	end
	if n == 0 then return end
	local tabS, closeS, gapT, gapR = 44, 50, 6, 14
	local function total() return 16 + n * tabS + (n - 1) * gapT + gapR + closeS end
	while total() > availH - 6 and tabS > 34 do tabS = tabS - 1 end
	if total() > availH - 6 then gapT, gapR = 3, 8 end
	while total() > availH - 6 and tabS > 28 do tabS = tabS - 1 end
	while total() > availH - 6 and closeS > 34 do closeS = closeS - 1 end
	railTabLayout.Padding = UDim.new(0, gapT)
	railLayout.Padding = UDim.new(0, gapR)
	for _, t in pairs(tabs) do
		t.btn.Size = UDim2.fromOffset(tabS, tabS)
		t.corner.CornerRadius = UDim.new(0, math.floor(tabS * 0.32))
		local px = math.floor(tabS * 0.45)
		t.icon.Size = UDim2.fromOffset(px, px)
	end
	closeBtn.Size = UDim2.fromOffset(closeS, closeS)
	if closeCorner then closeCorner.CornerRadius = UDim.new(0, math.floor(closeS / 2)) end
	local cpx = math.floor(closeS * 0.44)
	closeIc.Size = UDim2.fromOffset(cpx, cpx)
end
STATE.fitRail = fitRail
end

Tab("Home", "house", 0)
Tab("Editor", "code", 1)
Tab("ScriptBlox", "search", 2)
Tab("Console", "terminal", 3)
Tab("Updates", "scroll-text", 4)
Tab("Settings", "settings", 5)
STATE.applyConsole = function()
	tabs.Console.btn.Visible = SETTINGS.Console
	if not SETTINGS.Console and current == "Console" then showPage("Editor") end
	STATE.fitRail()
end
STATE.applyConsole()
bind(root:GetPropertyChangedSignal("AbsoluteSize"), function() STATE.fitRail() end)
bind(uiScale:GetPropertyChangedSignal("Scale"), function() STATE.fitRail() end)
task.defer(function() STATE.fitRail() end)
tabs.Updates.dot.Visible = unread

safeBuild("Home", function()
	local p = newPage("Home")
	local list = List(p, UDim2.fromOffset(14, 12), UDim2.new(1, -28, 1, -18))
	local ord = 0
	local function nextOrder() ord = ord + 1 return ord end
	local lp = Players.LocalPlayer

	local function section(text)
		local f = frame({ Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = nextOrder() }, list)
		local accent = frame({ Size = UDim2.fromOffset(3, 12), Position = UDim2.fromOffset(0, 3), BackgroundColor3 = C.red }, f)
		round(accent, 2)
		label({ Text = text:upper(), Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.sub, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -10, 1, 0) }, f)
	end

	local function box(order, pad)
		local f = frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.card, LayoutOrder = order }, list)
		round(f, 12)
		stroke(f, C.stroke, 1, 0.4)
		make("UIPadding", { PaddingTop = UDim.new(0, pad), PaddingBottom = UDim.new(0, pad), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, f)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, f)
		return f
	end

	local function grid(cellH, cols)
		local g = frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = nextOrder() }, list)
		make("UIGridLayout", {
			CellSize = cols == 1 and UDim2.new(1, 0, 0, cellH) or UDim2.new(0.5, -5, 0, cellH), CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder, FillDirectionMaxCells = cols,
		}, g)
		return g
	end

	local function avatar(parent, size, pos, letter)
		local holder = frame({ Size = UDim2.fromOffset(size, size), Position = pos, BackgroundColor3 = C.bg }, parent)
		round(holder, size / 2)
		stroke(holder, C.redHi, 2, 0.35)
		label({ Text = letter, Font = Enum.Font.GothamBold, TextSize = math.floor(size * 0.4), TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) }, holder)
		local img = make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ImageTransparency = 1, ScaleType = Enum.ScaleType.Crop, ZIndex = 2 }, holder)
		round(img, size / 2)
		return holder, img
	end

	local function loadRemoteAvatar(img, url, fname)
		task.spawn(function()
			local ok = pcall(function()
				local asset = getcustomasset or getsynasset
				if not asset or not canFile() then error("unsupported") end
				local path = FOLDER .. "/" .. fname
				if not isfile(path) then
					local body = httpGet(url)
					if not body then error("download failed") end
					fileWrite(fname, body)
				end
				img.Image = asset(path)
			end)
			if ok and alive and img.Parent then tween(img, 0.3, { ImageTransparency = 0 }) end
		end)
	end

	local function chip(parent, text, order)
		local c = frame({ Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.bg, BackgroundTransparency = 0.15, LayoutOrder = order }, parent)
		round(c, 10)
		stroke(c, C.stroke, 1, 0.5)
		make("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, c)
		return label({ Text = text, Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = C.sub, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0) }, c)
	end

	-- profile
	local prof = frame({ Size = UDim2.new(1, 0, 0, 100), BackgroundColor3 = C.white, LayoutOrder = nextOrder() }, list)
	round(prof, 14)
	stroke(prof, C.stroke, 1, 0.4)
	gradient(prof, P(52, 30, 40), P(24, 18, 26), 20)
	local _, pImg = avatar(prof, 68, UDim2.fromOffset(16, 16), lp.Name:sub(1, 1):upper())
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(lp.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok and url and alive and pImg.Parent then
			pImg.Image = url
			tween(pImg, 0.3, { ImageTransparency = 0 })
		end
	end)
	label({ Text = "WELCOME BACK", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.redHi, Position = UDim2.fromOffset(96, 14), Size = UDim2.new(1, -170, 0, 12) }, prof)
	label({ Text = lp.DisplayName, Font = Enum.Font.GothamBold, TextSize = 18, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(96, 27), Size = UDim2.new(1, -170, 0, 22) }, prof)
	label({ Text = "@" .. lp.Name, TextSize = 12, TextColor3 = C.sub, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(96, 50), Size = UDim2.new(1, -170, 0, 16) }, prof)
	local vpill = frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(54, 20), BackgroundColor3 = C.red, BackgroundTransparency = 0.8 }, prof)
	round(vpill, 10)
	label({ Text = "v" .. VERSION, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.redHi, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) }, vpill)
	local chips = frame({ Position = UDim2.fromOffset(96, 71), Size = UDim2.new(1, -110, 0, 20), BackgroundTransparency = 1 }, prof)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, chips)
	local exName = "Executor"
	if identifyexecutor then
		local okE, n = pcall(identifyexecutor)
		if okE and n then exName = tostring(n) end
	end
	chip(chips, exName, 1)
	local keyChip = chip(chips, "", 3)
	keyChip.Parent.Visible = false
	local keyState = { known = false, exp = nil }
	STATE.keyInfo = function(exp)
		keyState.known, keyState.exp = true, exp
		if keyChip.Parent then
			local text = "Lifetime key"
			if exp then
				local days = math.floor((exp - os.time()) / 86400)
				text = days <= 0 and "Expires today" or ("Expires in " .. days .. "d")
			end
			keyChip.Text = text
			keyChip.Parent.Visible = true
		end
	end
	local playersLbl = chip(chips, #Players:GetPlayers() .. " players", 2)
	task.spawn(function()
		while alive and playersLbl.Parent do
			task.wait(8)
			if playersLbl.Parent then playersLbl.Text = #Players:GetPlayers() .. " players" end
		end
	end)

	-- key status: green countdown ring + restore button
	if CONFIG.Key.Enabled then
		local S, T = 64, 5
		local kc = frame({ Size = UDim2.new(1, 0, 0, 88), BackgroundColor3 = C.card, LayoutOrder = nextOrder() }, list)
		round(kc, 14)
		stroke(kc, C.stroke, 1, 0.4)
		local ringBox = frame({ Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(S, S), BackgroundTransparency = 1 }, kc)
		local glow = make("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(S + 24, S + 24),
			BackgroundTransparency = 1, BorderSizePixel = 0, Image = "rbxassetid://5554236805", ImageColor3 = C.green, ImageTransparency = 0.75,
			ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(23, 23, 277, 277), SliceScale = 0.4, ZIndex = 0,
		}, ringBox)
		local disc = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(S - 2 * T - 4, S - 2 * T - 4), BackgroundColor3 = C.green, BackgroundTransparency = 0.88 }, ringBox)
		round(disc, 999)
		local track = frame({ Position = UDim2.fromOffset(T, T), Size = UDim2.fromOffset(S - 2 * T, S - 2 * T), BackgroundTransparency = 1 }, ringBox)
		round(track, 999)
		local trackStroke = stroke(track, C.green, T, 0.85)
		local function half(x, cx)
			local clip = frame({ Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(S / 2, S), BackgroundTransparency = 1, ClipsDescendants = true }, ringBox)
			local circ = frame({ Position = UDim2.fromOffset(cx, T), Size = UDim2.fromOffset(S - 2 * T, S - 2 * T), BackgroundTransparency = 1 }, clip)
			round(circ, 999)
			local st = stroke(circ, C.green, T, 0)
			local g = make("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1),
				}),
			}, st)
			return st, g
		end
		local rSt, rG = half(S / 2, T - S / 2)
		local lSt, lG = half(0, T)
		local headGlow = make("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, BorderSizePixel = 0,
			Image = "rbxassetid://5554236805", ImageColor3 = C.green, ImageTransparency = 0.5,
			ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(23, 23, 277, 277), SliceScale = 0.3, ZIndex = 3, Visible = false,
		}, ringBox)
		local headDot = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.white, ZIndex = 4, Visible = false }, ringBox)
		round(headDot, 4)
		local ctr = label({ Text = "--", Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, ringBox)

		label({ Text = "Access key", Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(92, 10), Size = UDim2.new(1, -106, 0, 18) }, kc)
		local statusLbl = label({ Text = "Not verified yet", TextSize = 11, TextColor3 = C.sub, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(92, 29), Size = UDim2.new(1, -106, 0, 14) }, kc)

		local function compute()
			local col, txt, p, status = C.green, "--", 0, "Not verified yet"
			if keyState.known then
				if keyState.exp then
					local rem = keyState.exp - os.time()
					if rem <= 0 then
						col, txt, p, status = C.red, "Expired", 0, "This key has expired"
					else
						p = math.clamp(rem / (30 * 86400), 0.04, 1)
						local d = math.floor(rem / 86400)
						if d >= 1 then
							txt = d .. "d " .. math.floor((rem % 86400) / 3600) .. "h"
						else
							txt = string.format("%02d:%02d:%02d", math.floor(rem / 3600), math.floor((rem % 3600) / 60), rem % 60)
						end
						if rem < 3600 then col = C.red elseif rem < 86400 then col = C.amber end
						status = "Expires " .. os.date("%b %d, %Y", keyState.exp)
					end
				else
					txt, p, status = "Lifetime", 1, "Never expires"
				end
			end
			return col, txt, p, status
		end

		local shown, colNow = 0, C.green
		bind(RS.RenderStepped, function(dt)
			if not alive or not kc.Parent then return end
			if not p.Visible then shown = 0 return end
			local col, txt, target, status = compute()
			shown = shown + (target - shown) * math.min(1, dt * 2.5)
			colNow = colNow:Lerp(col, math.min(1, dt * 6))
			local now = os.clock()
			rG.Rotation = math.clamp(shown * 360, 0, 180)
			lG.Rotation = math.clamp(shown * 360, 180, 360)
			rSt.Color, lSt.Color, trackStroke.Color, ctr.TextColor3 = colNow, colNow, colNow, colNow
			ctr.Text, statusLbl.Text = txt, status
			local urgent = (col == C.red or col == C.amber)
			local pulse = math.sin(now * (urgent and 5 or 2.2))
			glow.ImageColor3 = colNow
			glow.ImageTransparency = 0.72 + (urgent and 0.14 or 0.09) * pulse
			local gs = S + 24 + 4 * pulse
			glow.Size = UDim2.fromOffset(gs, gs)
			disc.BackgroundColor3 = colNow
			disc.BackgroundTransparency = 0.88 + 0.04 * pulse
			trackStroke.Transparency = 0.85 + 0.05 * math.sin(now * 1.3)
			local showHead = shown > 0.02 and shown < 0.995
			headDot.Visible, headGlow.Visible = showHead, showHead
			if showHead then
				local ang = math.rad(shown * 360 - 90)
				local rad = (S - T) / 2
				local pos = UDim2.fromOffset(S / 2 + math.cos(ang) * rad, S / 2 + math.sin(ang) * rad)
				headDot.Position, headGlow.Position = pos, pos
				headGlow.ImageColor3 = colNow
				headGlow.ImageTransparency = 0.45 + 0.15 * pulse
			end
		end)

		local rb = Btn(kc, { Text = "Restore key", Icon = "refresh-cw", Size = UDim2.fromOffset(132, 26), Position = UDim2.fromOffset(92, 52), Radius = 8, TextSize = 12, IconSize = 13 })
		local rbusy = false
		bind(rb.Button.MouseButton1Click, function()
			if rbusy then return end
			rbusy = true
			setBtn(rb, "Checking", "loader-circle")
			spin(rb.Icon)
			local ok, msg
			if STATE.restoreKey then ok, msg = STATE.restoreKey() else ok, msg = false, "Key system isn't ready yet" end
			unspin(rb.Icon)
			if not alive then return end
			if ok then
				setBtn(rb, "Restored", "check")
				Notify({ Title = "Key restored", Text = "Your saved key is valid.", Type = "success", Icon = "shield-check", Duration = 3 })
			else
				setBtn(rb, "Failed", "x")
				Notify({ Title = "Couldn't restore key", Text = tostring(msg), Type = "error", Duration = 4 })
			end
			for sec = 6, 1, -1 do
				if not alive or not kc.Parent then return end
				setBtn(rb, "Wait " .. sec .. "s")
				task.wait(1)
			end
			setBtn(rb, "Restore key", "refresh-cw")
			rbusy = false
		end)
	end

	-- latest update
	section("Latest update")
	local rel = CHANGELOG[1]
	if rel then
		local TAGS = { new = { "circle-plus", C.green }, improved = { "sparkles", C.blue }, fix = { "wrench", C.amber }, removed = { "trash", C.red } }
		local blk = box(nextOrder(), 12)
		local head = frame({ Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = 1 }, blk)
		label({ Text = "v" .. rel.version, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.redHi, Size = UDim2.fromOffset(52, 22) }, head)
		label({ Text = rel.date, TextSize = 11, TextColor3 = C.sub, Position = UDim2.fromOffset(54, 0), Size = UDim2.fromOffset(80, 22) }, head)
		local all = Btn(head, { Text = "View all", Icon = "arrow-right", Style = "ghost", Size = UDim2.fromOffset(86, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Radius = 8, TextSize = 11, IconSize = 12 })
		bind(all.Button.MouseButton1Click, function() showPage("Updates") end)
		label({ Text = rel.title, Font = Enum.Font.GothamMedium, TextSize = 12, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2 }, blk)
		for j = 1, math.min(3, #rel.changes) do
			local ch = rel.changes[j]
			local tag = TAGS[ch[1]] or TAGS.new
			local row = frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 + j }, blk)
			local ic = Icon(row, tag[1], 14, tag[2])
			ic.Position = UDim2.fromOffset(0, 1)
			label({
				Text = ch[2], TextSize = 12, TextColor3 = C.sub, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			}, row)
		end
		if #rel.changes > 3 then
			label({ Text = "+" .. (#rel.changes - 3) .. " more in the Updates tab", TextSize = 11, TextColor3 = P(110, 95, 104), Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 9 }, blk)
		end
	end

	-- quick access (tap a tile to run)
	section("Quick access")
	local quick = {}
	for _, q in ipairs(CONFIG.QuickScripts or {}) do quick[#quick + 1] = q end
	for _, q in ipairs(SCRIPTS) do
		if q.url or q.slug then quick[#quick + 1] = q end
	end
	if #quick == 0 then
		label({ Text = "No quick scripts yet. Add some in CONFIG.QuickScripts.", TextSize = 12, TextColor3 = C.sub, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = nextOrder() }, list)
	else
		local qg = grid(64, #quick == 1 and 1 or 2)
		for i, q in ipairs(quick) do
			local tile = make("TextButton", { BackgroundColor3 = C.card, Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i }, qg)
			round(tile, 12)
			local st = stroke(tile, C.stroke, 1, 0.4)
			local ibox = frame({ Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(12, 13), BackgroundColor3 = C.bg }, tile)
			round(ibox, 10)
			local ic = Icon(ibox, q.icon or "zap", 18, C.red)
			ic.AnchorPoint = Vector2.new(0.5, 0.5)
			ic.Position = UDim2.fromScale(0.5, 0.5)
			label({ Text = q.name, Font = Enum.Font.GothamBold, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(60, 13), Size = UDim2.new(1, -68, 0, 18) }, tile)
			local sub = label({ Text = q.desc or "Tap to run", TextSize = 11, TextColor3 = C.sub, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(60, 33), Size = UDim2.new(1, -68, 0, 16) }, tile)
			bind(tile.MouseEnter, function() tween(st, 0.15, { Color = C.red, Transparency = 0.1 }) end)
			bind(tile.MouseLeave, function() tween(st, 0.15, { Color = C.stroke, Transparency = 0.4 }) end)
			local busy = false
			bind(tile.MouseButton1Click, function()
				if busy then return end
				busy = true
				sub.Text, sub.TextColor3 = "Running...", C.sub
				local src, err = fetchEntrySource(q)
				local ok = false
				if src then ok, err = runCode(src) end
				if not alive then return end
				if ok then
					sub.Text, sub.TextColor3 = "Executed", C.green
					Notify({ Title = "Executed", Text = q.name, Type = "success", Duration = 3 })
				else
					sub.Text, sub.TextColor3 = "Failed", C.red
					warn("[Shadow] " .. tostring(err))
					Notify({ Title = "Execution failed", Text = tostring(err):sub(1, 90), Type = "error", Duration = 6 })
				end
				task.delay(2.5, function()
					if alive and tile.Parent then sub.Text, sub.TextColor3 = q.desc or "Tap to run", C.sub end
				end)
				busy = false
			end)
		end
	end

	-- credits
	section("Credits")
	local devs = CONFIG.Developers or {}
	local cg = grid(114, #devs == 1 and 1 or 2)
	for i, d in ipairs(devs) do
		local card = frame({ BackgroundColor3 = C.card, LayoutOrder = i }, cg)
		round(card, 12)
		stroke(card, C.stroke, 1, 0.4)
		local _, img = avatar(card, 48, UDim2.new(0.5, -24, 0, 12), tostring(d.name):sub(1, 1):upper())
		label({ Text = d.role, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.redHi, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(6, 66), Size = UDim2.new(1, -12, 0, 14) }, card)
		label({ Text = d.name, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(6, 82), Size = UDim2.new(1, -12, 0, 20) }, card)
		if d.avatar and d.avatar ~= "" then loadRemoteAvatar(img, d.avatar, "avatar_" .. (d.avatar:match("/(%w+)%.%w+%?") or i) .. ".png") end
	end

	local dBtn = Btn(list, { Text = "Join our Discord", Icon = "link", Style = "blurple", Size = UDim2.new(1, 0, 0, 38), LayoutOrder = nextOrder(), Radius = 12, TextSize = 13 })
	bind(dBtn.Button.MouseButton1Click, function()
		if copyText(CONFIG.Discord) then
			Notify({ Title = "Discord link copied", Text = "Paste it in your browser to join.", Type = "info", Icon = "link", Duration = 3 })
		else
			Notify({ Title = "Join our Discord", Text = CONFIG.Discord, Type = "info", Icon = "link", Duration = 8 })
		end
	end)
end)

safeBuild("Editor", function()
	local p = newPage("Editor")
	local PAD, GAP = 10, 8
	local SIDE_PW = math.clamp(math.floor(WIN_W * 0.3), 170, 260)
	local sideOpen = WIN_W >= 440
	local FONT, FSIZE = Enum.Font.Code, 13

	local function set(list)
		local t = {}
		for _, w in ipairs(list) do t[w] = true end
		return t
	end
	local KEYWORDS = set({ "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue" })
	local BUILTINS = set({ "game", "workspace", "script", "print", "warn", "error", "pcall", "xpcall", "pairs", "ipairs", "next", "tostring", "tonumber", "type", "typeof", "select", "unpack", "require", "loadstring", "task", "math", "string", "table", "os", "Instance", "Vector3", "Vector2", "CFrame", "Color3", "UDim2", "Enum", "wait", "spawn", "delay", "setmetatable", "getmetatable", "rawget", "rawset", "assert", "tick", "time", "coroutine", "getgenv", "shared", "_G" })
	local COL = { kw = "#c792ea", str = "#a5e075", num = "#f0b86e", com = "#6e6a86", bi = "#6cb6ff" }

	local function esc2(str)
		str = str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;")
		return str
	end

	local function highlight(src)
		local out, buf = {}, {}
		local i, n = 1, #src
		local function flush()
			if #buf > 0 then
				out[#out + 1] = esc2(table.concat(buf))
				buf = {}
			end
		end
		local function push(text, color)
			flush()
			out[#out + 1] = '<font color="' .. color .. '">' .. esc2(text) .. "</font>"
		end
		while i <= n do
			local c = src:sub(i, i)
			if src:sub(i, i + 1) == "--" then
				local lvl = src:match("^%-%-%[(=*)%[", i)
				local e
				if lvl then
					local _, ce = src:find("]" .. lvl .. "]", i, true)
					e = ce or n
				else
					e = (src:find("\n", i, true) or (n + 1)) - 1
				end
				push(src:sub(i, e), COL.com)
				i = e + 1
			elseif c == '"' or c == "'" then
				local j = i + 1
				while j <= n do
					local d = src:sub(j, j)
					if d == "\\" then j = j + 2
					elseif d == c or d == "\n" then break
					else j = j + 1 end
				end
				j = math.min(j, n)
				push(src:sub(i, j), COL.str)
				i = j + 1
			elseif c == "[" and src:match("^%[(=*)%[", i) then
				local lvl = src:match("^%[(=*)%[", i)
				local _, ce = src:find("]" .. lvl .. "]", i, true)
				local e = ce or n
				push(src:sub(i, e), COL.str)
				i = e + 1
			elseif c:match("%d") or (c == "." and src:sub(i + 1, i + 1):match("%d")) then
				local num = src:match("^0[xX]%x+", i) or src:match("^%d*%.?%d+[eE][%+%-]?%d+", i) or src:match("^%d*%.?%d*", i)
				if not num or #num == 0 then num = c end
				push(num, COL.num)
				i = i + #num
			elseif c:match("[%a_]") then
				local word = src:match("^[%w_]+", i)
				if KEYWORDS[word] then push(word, COL.kw)
				elseif BUILTINS[word] then push(word, COL.bi)
				else buf[#buf + 1] = word end
				i = i + #word
			else
				buf[#buf + 1] = c
				i = i + 1
			end
		end
		flush()
		return table.concat(out)
	end

	local EDIT = { tabs = {}, active = 1 }
	local SAVED = {}
	do
		local raw = fileRead("editor.json")
		if raw and raw ~= "" then
			local ok, d = pcall(function() return HttpService:JSONDecode(raw) end)
			if ok and type(d) == "table" and type(d.tabs) == "table" then
				for _, t in ipairs(d.tabs) do
					if type(t) == "table" and type(t.name) == "string" and type(t.code) == "string" then
						EDIT.tabs[#EDIT.tabs + 1] = { name = t.name, code = t.code }
					end
				end
				if type(d.active) == "number" then EDIT.active = d.active end
			end
		end
		raw = fileRead("saved.json")
		if raw and raw ~= "" then
			local ok, d = pcall(function() return HttpService:JSONDecode(raw) end)
			if ok and type(d) == "table" and type(d.scripts) == "table" then
				for _, t in ipairs(d.scripts) do
					if type(t) == "table" and type(t.name) == "string" and type(t.code) == "string" then
						SAVED[#SAVED + 1] = { name = t.name, code = t.code }
					end
				end
			end
		end
	end
	if #EDIT.tabs == 0 then EDIT.tabs[1] = { name = "New tab", code = "" } end
	EDIT.active = math.clamp(EDIT.active, 1, #EDIT.tabs)

	local saveToken = 0
	local function persistEditor()
		saveToken = saveToken + 1
		local tok = saveToken
		task.delay(0.8, function()
			if tok ~= saveToken or not alive then return end
			pcall(function() fileWrite("editor.json", HttpService:JSONEncode({ tabs = EDIT.tabs, active = EDIT.active })) end)
		end)
	end
	local function persistSaved()
		pcall(function() fileWrite("saved.json", HttpService:JSONEncode({ scripts = SAVED })) end)
	end
	local function currentTab() return EDIT.tabs[EDIT.active] end

	local function MiniBtn(parent, iconName, px, props)
		props.BackgroundTransparency = 1
		props.Text = ""
		props.AutoButtonColor = false
		props.BorderSizePixel = 0
		local b = make("TextButton", props, parent)
		local ic = Icon(b, iconName, px, C.sub)
		ic.AnchorPoint = Vector2.new(0.5, 0.5)
		ic.Position = UDim2.fromScale(0.5, 0.5)
		b.MouseEnter:Connect(function() tintIcon(ic, C.white) end)
		b.MouseLeave:Connect(function() tintIcon(ic, C.sub) end)
		return b, ic
	end

	local function Panel(props, parent)
		props.BorderSizePixel = 0
		local f = make("Frame", props, parent)
		round(f, 18)
		stroke(f, C.stroke, 1, 0.35)
		return f
	end

	local sidePanel = Panel({
		Name = "SidePanel", Position = UDim2.fromOffset(PAD, PAD), Size = UDim2.new(0, sideOpen and SIDE_PW or 0, 1, -PAD * 2),
		BackgroundColor3 = C.bg2, ClipsDescendants = true, Visible = sideOpen,
	}, p)

	local head = frame({ Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }, sidePanel)
	table.insert(STATE.dragTargets, head)
	frame({ Size = UDim2.new(1, 0, 0, 1), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.stroke, BackgroundTransparency = 0.5 }, head)
	local brand = Icon(head, "ghost", 22, C.redHi)
	brand.Position = UDim2.fromOffset(12, 13)
	label({ Text = "Editor", Font = Enum.Font.GothamBold, TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -(38 + 44), 1, 0) }, head)
	local collapseBtn = MiniBtn(head, "panel-left", 16, { Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0) })

	local sideScroll = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 49), Size = UDim2.new(1, 0, 1, -49), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 2, ScrollBarImageColor3 = C.red, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, sidePanel)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, sideScroll)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }, sideScroll)

	local function Section(title, order)
		local row = frame({ Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = order }, sideScroll)
		label({ Text = title, Font = Enum.Font.GothamBold, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -40, 1, 0) }, row)
		local plus = MiniBtn(row, "plus", 16, { Size = UDim2.fromOffset(26, 26), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0) })
		return plus
	end
	local newTabBtn = Section("Tabs", 1)
	local tabsBox = frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, sideScroll)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, tabsBox)
	frame({ Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, LayoutOrder = 3 }, sideScroll)
	local saveBtn = Section("Saved scripts", 4)
	local savedBox = frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 5 }, sideScroll)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }, savedBox)

	local startX = PAD + (sideOpen and (SIDE_PW + GAP) or 0)
	local codePanel = Panel({
		Name = "CodePanel", Position = UDim2.fromOffset(startX, PAD), Size = UDim2.new(1, -(PAD + startX), 1, -PAD * 2),
		BackgroundColor3 = C.bg, ClipsDescendants = true,
	}, p)

	local gutterClip = frame({ Position = UDim2.fromOffset(6, 8), Size = UDim2.new(0, 34, 1, -16), BackgroundTransparency = 1, ClipsDescendants = true }, codePanel)
	local gutter = label({
		Text = "1", Font = FONT, TextSize = FSIZE, TextColor3 = P(110, 95, 104), TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -6, 0, 100),
	}, gutterClip)

	local scroller = make("ScrollingFrame", {
		Position = UDim2.fromOffset(44, 8), Size = UDim2.new(1, -52, 1, -16), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, ScrollBarImageColor3 = C.red, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.XY,
	}, codePanel)

	local hl = label({
		Text = "", RichText = true, Font = FONT, TextSize = FSIZE, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = false, Size = UDim2.fromOffset(200, 100),
	}, scroller)
	local box = make("TextBox", {
		Text = "", Font = FONT, TextSize = FSIZE, TextColor3 = C.text, TextTransparency = 1, BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = false,
		MultiLine = true, ClearTextOnFocus = false, PlaceholderText = "-- Write or paste a script here",
		PlaceholderColor3 = P(110, 95, 104), Size = UDim2.fromOffset(200, 100), ZIndex = 2,
	}, scroller)

	local function relayout()
		local tb = box.TextBounds
		local w = math.max(scroller.AbsoluteSize.X - 8, tb.X + 40)
		local h = math.max(scroller.AbsoluteSize.Y - 64, tb.Y + 12)
		box.Size = UDim2.fromOffset(w, h)
		hl.Size = UDim2.fromOffset(w, h)
		scroller.CanvasSize = UDim2.fromOffset(w, h + 64)
		gutter.Size = UDim2.new(1, -6, 0, h)
	end
	local function updateGutter()
		local _, n = box.Text:gsub("\n", "\n")
		local lines = {}
		for i = 1, n + 1 do lines[i] = tostring(i) end
		gutter.Text = table.concat(lines, "\n")
	end
	local function updateHL()
		local txt = box.Text
		if #txt > 6000 then
			box.TextTransparency = 0
			hl.Visible = false
		else
			box.TextTransparency = 1
			hl.Visible = true
			hl.Text = highlight(txt)
		end
	end
	local function ensureCursor()
		local cp = box.CursorPosition
		if cp < 1 then return end
		local _, before = box.Text:sub(1, cp - 1):gsub("\n", "\n")
		local _, total = box.Text:gsub("\n", "\n")
		local lineH = box.TextBounds.Y / math.max(total + 1, 1)
		if lineH <= 0 then return end
		local y = before * lineH
		local view = scroller.AbsoluteSize.Y - 64
		local cur = scroller.CanvasPosition
		if y < cur.Y then
			scroller.CanvasPosition = Vector2.new(cur.X, y)
		elseif y + lineH > cur.Y + view then
			scroller.CanvasPosition = Vector2.new(cur.X, y + lineH - view)
		end
	end

	bind(scroller:GetPropertyChangedSignal("CanvasPosition"), function()
		gutter.Position = UDim2.fromOffset(0, -scroller.CanvasPosition.Y)
	end)
	bind(scroller:GetPropertyChangedSignal("AbsoluteSize"), relayout)
	bind(box:GetPropertyChangedSignal("TextBounds"), relayout)
	bind(box:GetPropertyChangedSignal("CursorPosition"), ensureCursor)

	local reopenBtn = MiniBtn(codePanel, "panel-left", 16, { Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), ZIndex = 6, Visible = not sideOpen })

	local toolbar = frame({
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(0, 48),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.bg2, BackgroundTransparency = 0.08, ZIndex = 5,
	}, codePanel)
	round(toolbar, 16)
	stroke(toolbar, C.stroke, 1, 0.3)
	make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, toolbar)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6) }, toolbar)
	local function ToolBtn(iconName, order)
		return IconBtn(toolbar, iconName, 19, { Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.bg2, LayoutOrder = order, ZIndex = 5 })
	end
	local clearBtn = ToolBtn("trash", 1)
	local renameBtn = ToolBtn("pencil", 2)
	local copyBtn = ToolBtn("clipboard", 3)
	local saveToolBtn = ToolBtn("save", 4)
	frame({ Size = UDim2.fromOffset(1, 22), BackgroundColor3 = C.stroke, BackgroundTransparency = 0.3, LayoutOrder = 5 }, toolbar)
	local runBtn, runIc = ToolBtn("play", 6)
	tintIcon(runIc, C.green)
	bind(runBtn.MouseLeave, function() tintIcon(runIc, C.green) end)

	local overlay = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 30, Active = true }, p)
	NoTheme(overlay)
	local dlg = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(250, 124), BackgroundColor3 = C.bg2 }, overlay)
	round(dlg, 14)
	stroke(dlg, C.stroke, 1, 0.2)
	label({ Text = "Rename tab", Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 18) }, dlg)
	local nameWrap = frame({ Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 32), BackgroundColor3 = C.card }, dlg)
	round(nameWrap, 8)
	local nameStroke = stroke(nameWrap, C.stroke, 1, 0.3)
	local nameBox = make("TextBox", {
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, Text = "",
		PlaceholderText = "Tab name", PlaceholderColor3 = P(110, 95, 104), TextColor3 = C.text, Font = Enum.Font.Gotham,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ClipsDescendants = true,
	}, nameWrap)
	bind(nameBox.Focused, function() tween(nameStroke, 0.15, { Color = C.red, Transparency = 0.1 }) end)
	bind(nameBox.FocusLost, function() tween(nameStroke, 0.15, { Color = C.stroke, Transparency = 0.3 }) end)
	local cancelBtn = Btn(dlg, { Text = "Cancel", Icon = "x", Style = "ghost", Size = UDim2.fromOffset(104, 30), Position = UDim2.new(0, 14, 1, -42) })
	local okBtn = Btn(dlg, { Text = "Save", Icon = "check", Size = UDim2.fromOffset(104, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 1, -42) })

	local renderTabs, renderSaved
	local renameCb
	local function promptRename(cb)
		renameCb = cb
		nameBox.Text = currentTab().name
		overlay.Visible = true
		nameBox:CaptureFocus()
	end
	local function closeRename() overlay.Visible = false end
	local function confirmRename()
		local nm = trim(nameBox.Text)
		if nm == "" then
			Notify({ Title = "Name is empty", Text = "Type a name for the tab.", Type = "warn", Duration = 2.5 })
			return
		end
		currentTab().name = nm
		renderTabs()
		persistEditor()
		closeRename()
		local cb = renameCb
		renameCb = nil
		if cb then cb() end
	end
	bind(cancelBtn.Button.MouseButton1Click, function() renameCb = nil closeRename() end)
	bind(okBtn.Button.MouseButton1Click, confirmRename)
	bind(nameBox.FocusLost, function(enter) if enter then confirmRename() end end)

	local loading = false
	local function updateAll()
		updateGutter()
		updateHL()
		relayout()
	end
	local function loadActive()
		loading = true
		box.Text = currentTab().code
		loading = false
		updateAll()
		scroller.CanvasPosition = Vector2.new(0, 0)
	end
	bind(box:GetPropertyChangedSignal("Text"), function()
		if loading then return end
		currentTab().code = box.Text
		updateAll()
		persistEditor()
	end)

	local function switchTab(i)
		EDIT.active = math.clamp(i, 1, #EDIT.tabs)
		loadActive()
		renderTabs()
		persistEditor()
	end
	local function newTab(name, code)
		EDIT.tabs[#EDIT.tabs + 1] = { name = name or "New tab", code = code or "" }
		switchTab(#EDIT.tabs)
	end
	local function closeTab(i)
		if #EDIT.tabs == 1 then
			EDIT.tabs[1] = { name = "New tab", code = "" }
			switchTab(1)
			return
		end
		table.remove(EDIT.tabs, i)
		if EDIT.active > #EDIT.tabs then EDIT.active = #EDIT.tabs
		elseif i < EDIT.active then EDIT.active = EDIT.active - 1 end
		switchTab(EDIT.active)
	end

	local function openScript(name, code)
		for i, t in ipairs(EDIT.tabs) do
			if t.name == name and t.code == code then
				switchTab(i)
				return
			end
		end
		local cur = currentTab()
		if cur.code == "" and cur.name == "New tab" then
			cur.name, cur.code = name, code
			loadActive()
			renderTabs()
			persistEditor()
			return
		end
		newTab(name, code)
	end

	local function saveCurrent()
		local t = currentTab()
		if trim(t.code) == "" then
			Notify({ Title = "Nothing to save", Text = "The editor is empty.", Type = "warn", Duration = 2.5 })
			return
		end
		if t.name == "New tab" then
			promptRename(saveCurrent)
			return
		end
		for _, s2 in ipairs(SAVED) do
			if s2.name == t.name then
				s2.code = t.code
				persistSaved()
				renderSaved()
				Notify({ Title = "Script updated", Text = t.name, Type = "success", Icon = "star", Duration = 2.5 })
				return
			end
		end
		SAVED[#SAVED + 1] = { name = t.name, code = t.code }
		persistSaved()
		renderSaved()
		Notify({ Title = "Saved", Text = t.name, Type = "success", Icon = "star", Duration = 2.5 })
	end

	local function clearBox(container)
		for _, c in ipairs(container:GetChildren()) do
			if c:IsA("GuiObject") then c:Destroy() end
		end
	end

	renderTabs = function()
		clearBox(tabsBox)
		for i, t in ipairs(EDIT.tabs) do
			local on = (i == EDIT.active)
			local row = make("TextButton", {
				Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.red, BackgroundTransparency = on and 0.84 or 1,
				Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i,
			}, tabsBox)
			round(row, 10)
			local ibox = frame({ Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.red, BackgroundTransparency = on and 0.7 or 1 }, row)
			round(ibox, 7)
			local ic = Icon(ibox, "file-code", 14, on and C.redHi or C.sub)
			ic.AnchorPoint = Vector2.new(0.5, 0.5)
			ic.Position = UDim2.fromScale(0.5, 0.5)
			label({
				Text = t.name, Font = on and Enum.Font.GothamMedium or Enum.Font.Gotham, TextSize = 13,
				TextColor3 = on and C.redHi or C.sub, TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -66, 1, 0),
			}, row)
			local x = MiniBtn(row, "x", 13, { Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0) })
			x.MouseButton1Click:Connect(function() closeTab(i) end)
			row.MouseButton1Click:Connect(function()
				if i ~= EDIT.active then switchTab(i) end
			end)
		end
	end

	renderSaved = function()
		clearBox(savedBox)
		local items = {}
		for _, s2 in ipairs(SCRIPTS) do
			if s2.url or s2.slug then
				items[#items + 1] = { name = s2.name, code = 'loadstring(game:HttpGet("' .. (s2.url or (SB_RAW .. s2.slug)) .. '"))()', builtin = true }
			end
		end
		for i, s2 in ipairs(SAVED) do
			items[#items + 1] = { name = s2.name, code = s2.code, idx = i }
		end
		for i, it in ipairs(items) do
			local row = make("TextButton", {
				Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.red, BackgroundTransparency = 1,
				Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i,
			}, savedBox)
			round(row, 10)
			local star = Icon(row, "star", 17, C.amber)
			star.Position = UDim2.fromOffset(9, 9)
			label({
				Text = it.name, TextSize = 13, TextColor3 = C.text, TextTruncate = Enum.TextTruncate.AtEnd,
				Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, it.builtin and -42 or -68, 1, 0),
			}, row)
			if not it.builtin then
				local del = MiniBtn(row, "trash", 13, { Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0) })
				del.MouseButton1Click:Connect(function()
					table.remove(SAVED, it.idx)
					persistSaved()
					renderSaved()
				end)
			end
			row.MouseEnter:Connect(function() tween(row, 0.12, { BackgroundTransparency = 0.9 }) end)
			row.MouseLeave:Connect(function() tween(row, 0.12, { BackgroundTransparency = 1 }) end)
			row.MouseButton1Click:Connect(function() openScript(it.name, it.code) end)
		end
	end

	local function setSide(open, instant)
		sideOpen = open
		local sw = open and SIDE_PW or 0
		local cx = PAD + (open and (SIDE_PW + GAP) or 0)
		local d = instant and 0 or 0.25
		sidePanel.Visible = true
		tween(sidePanel, d, { Size = UDim2.new(0, sw, 1, -PAD * 2) }, Enum.EasingStyle.Quint)
		tween(codePanel, d, { Position = UDim2.fromOffset(cx, PAD), Size = UDim2.new(1, -(PAD + cx), 1, -PAD * 2) }, Enum.EasingStyle.Quint)
		reopenBtn.Visible = not open
		scroller.Size = UDim2.new(1, open and -52 or -88, 1, -16)
		if not open then
			task.delay(d + 0.02, function()
				if alive and not sideOpen then sidePanel.Visible = false end
			end)
		end
	end
	bind(collapseBtn.MouseButton1Click, function() setSide(false) end)
	bind(reopenBtn.MouseButton1Click, function() setSide(true) end)

	bind(newTabBtn.MouseButton1Click, function() newTab("New tab", "") end)
	bind(saveBtn.MouseButton1Click, saveCurrent)
	bind(saveToolBtn.MouseButton1Click, saveCurrent)
	bind(clearBtn.MouseButton1Click, function()
		box.Text = ""
	end)
	bind(renameBtn.MouseButton1Click, function() promptRename(nil) end)
	bind(copyBtn.MouseButton1Click, function()
		if trim(box.Text) == "" then
			Notify({ Title = "Nothing to copy", Text = "The editor is empty.", Type = "warn", Duration = 2.5 })
		elseif copyText(box.Text) then
			Notify({ Title = "Copied", Text = "Script copied to clipboard.", Type = "success", Duration = 2.5 })
		else
			Notify({ Title = "Can't copy", Text = "Your executor has no clipboard function.", Type = "warn" })
		end
	end)

	local running = false
	bind(runBtn.MouseButton1Click, function()
		if running then return end
		local src = box.Text
		if trim(src) == "" then
			Notify({ Title = "Nothing to run", Text = "The editor is empty.", Type = "warn", Duration = 2.5 })
			return
		end
		running = true
		setIcon(runIc, "loader-circle")
		spin(runIc)
		local done, ok, err = false, false, nil
		task.spawn(function()
			ok, err = runCode(src)
			done = true
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 0.6 do task.wait() end
		unspin(runIc)
		setIcon(runIc, "play")
		tintIcon(runIc, C.green)
		running = false
		if done and not ok then
			warn("[Shadow] " .. tostring(err))
			Notify({ Title = "Execution failed", Text = tostring(err):sub(1, 90), Type = "error", Duration = 6 })
		else
			Notify({ Title = "Executed", Text = currentTab().name, Type = "success", Duration = 2.5 })
		end
	end)

	setSide(sideOpen, true)
	renderTabs()
	renderSaved()
	loadActive()
end)

safeBuild("ScriptBlox", function()
	local p = newPage("ScriptBlox")
	local PADX = 14
	local TOP = 60

	local pillW = math.min(380, WIN_W - 40)
	local searchWrap = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(pillW, 36), BackgroundColor3 = C.bg2 }, p)
	round(searchWrap, 18)
	local sws = stroke(searchWrap, C.red, 1.5, 0.45)
	local sIcon = Icon(searchWrap, "search", 16, C.sub)
	sIcon.Position = UDim2.fromOffset(14, 10)
	local box = make("TextBox", {
		Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -84, 1, 0), BackgroundTransparency = 1,
		Text = "", PlaceholderText = "Search for scripts", PlaceholderColor3 = P(110, 95, 104),
		TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false, ClipsDescendants = true,
	}, searchWrap)
	bind(box.Focused, function() tween(sws, 0.15, { Transparency = 0 }) end)
	bind(box.FocusLost, function() tween(sws, 0.15, { Transparency = 0.45 }) end)
	local goBtn = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = C.white, Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, searchWrap)
	round(goBtn, 14)
	gradient(goBtn, C.redHi, C.red2, 90)
	local goIcon = Icon(goBtn, "arrow-right", 14, C.white)
	goIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	goIcon.Position = UDim2.fromScale(0.5, 0.5)

	local cardW = math.clamp(math.floor((WIN_W - PADX * 2 - 20) / 3), 128, 210)
	local coverH = math.floor(cardW * 0.58)
	local cardH = coverH + 46

	local gca = getcustomasset or getsynasset
	local thumbCache, thumbQueue, thumbWorker = {}, {}, false
	local function absImg(u)
		if type(u) ~= "string" or u == "" then return nil end
		if u:sub(1, 4) == "http" then return u end
		if u:sub(1, 1) ~= "/" then u = "/" .. u end
		return "https://scriptblox.com" .. u
	end
	local function runThumbs()
		if thumbWorker then return end
		thumbWorker = true
		task.spawn(function()
			while alive and #thumbQueue > 0 do
				local job = table.remove(thumbQueue, 1)
				if job.img.Parent then
					local asset = thumbCache[job.url]
					if not asset then
						local ext = job.url:match("%.(%a+)[%?#]?[^/]*$")
						ext = ext and ext:lower()
						if ext == "png" or ext == "jpg" or ext == "jpeg" then
							local data = httpGet(job.url)
							if data then
								local fname = "thumb_" .. job.url:gsub("[^%w]", ""):sub(-40) .. "." .. ext
								fileWrite(fname, data)
								local ok, a = pcall(gca, FOLDER .. "/" .. fname)
								if ok and a then
									asset = a
									thumbCache[job.url] = a
								end
							end
						end
					end
					if asset and job.img.Parent then
						job.img.Image = asset
						tween(job.img, 0.3, { ImageTransparency = 0 })
					end
				end
				task.wait(0.05)
			end
			thumbWorker = false
		end)
	end
	local function queueThumb(img, url)
		if not gca or not canFile() or not url then return end
		thumbQueue[#thumbQueue + 1] = { img = img, url = url }
		runThumbs()
	end
	local function thumbUrl(s2)
		local g = type(s2.game) == "table" and s2.game or nil
		return absImg(s2.image) or (g and absImg(g.imageUrl)) or nil
	end
	local function hashHue(str)
		local h = 0
		for i = 1, #str do h = (h * 31 + string.byte(str, i)) % 360 end
		return h / 360
	end
	local function initials(str)
		local t = {}
		for w in tostring(str):gmatch("%S+") do
			local ch = w:match("%w")
			if ch and #t < 2 then t[#t + 1] = ch:upper() end
		end
		return #t > 0 and table.concat(t) or "?"
	end
	local function gameName(s2) return (type(s2.game) == "table" and s2.game.name) or "Universal" end

	local function runScript(s2, onStart, onEnd)
		if onStart then onStart() end
		local done, ok, err = false, false, nil
		task.spawn(function()
			local src = (type(s2.script) == "string" and #s2.script > 0) and s2.script or nil
			if not src and s2.slug then src = httpGet(SB_RAW .. s2.slug) end
			if not src then
				ok, err = false, "Could not fetch this script"
			else
				ok, err = runCode(src)
			end
			done = true
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 0.8 do task.wait() end
		local failed = done and not ok
		if failed then
			warn("[Shadow] " .. tostring(err))
			Notify({ Title = "Execution failed", Text = tostring(err):sub(1, 90), Type = "error", Duration = 6 })
		else
			Notify({ Title = "Executed", Text = s2.title or "Script", Type = "success", Duration = 3 })
		end
		if onEnd then onEnd(failed) end
	end
	local function copyLoadstring(s2)
		local text
		if s2.slug then text = 'loadstring(game:HttpGet("' .. SB_RAW .. s2.slug .. '"))()' else text = type(s2.script) == "string" and s2.script or nil end
		if text and copyText(text) then
			Notify({ Title = "Copied", Text = "Loadstring copied to clipboard", Type = "success", Duration = 2.5 })
		else
			Notify({ Title = "Can't copy", Text = "Your executor has no clipboard function", Type = "warn" })
		end
	end

	local home = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, TOP), Size = UDim2.new(1, 0, 1, -TOP), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.red, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, p)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 12) }, home)
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, PADX), PaddingRight = UDim.new(0, PADX) }, home)

	local gridHead = frame({ Position = UDim2.fromOffset(0, TOP), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Visible = false }, p)
	local backBtn = make("TextButton", { Position = UDim2.fromOffset(PADX, 4), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = C.card, Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, gridHead)
	round(backBtn, 15)
	local backIc = Icon(backBtn, "chevron-left", 16, C.text)
	backIc.AnchorPoint = Vector2.new(0.5, 0.5)
	backIc.Position = UDim2.fromScale(0.5, 0.5)
	local gridTitle = label({ Text = "", Font = Enum.Font.GothamBold, TextSize = 16, Position = UDim2.fromOffset(PADX + 40, 2), Size = UDim2.new(1, -(PADX * 2 + 40), 0, 20), TextTruncate = Enum.TextTruncate.AtEnd }, gridHead)
	local gridSub = label({ Text = "", TextSize = 11, TextColor3 = C.sub, Position = UDim2.fromOffset(PADX + 40, 22), Size = UDim2.new(1, -(PADX * 2 + 40), 0, 14), TextTruncate = Enum.TextTruncate.AtEnd }, gridHead)

	local grid = make("ScrollingFrame", {
		Position = UDim2.fromOffset(0, TOP + 40), Size = UDim2.new(1, 0, 1, -(TOP + 40)), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.red, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Visible = false,
	}, p)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(cardW, cardH), CellPadding = UDim2.fromOffset(10, 14), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, PADX), PaddingRight = UDim.new(0, PADX) }, grid)

	local stateBox = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.58, 0), Size = UDim2.fromOffset(240, 60), BackgroundTransparency = 1, Visible = false }, p)
	local stateIcon = Icon(stateBox, "loader-circle", 22, C.sub)
	stateIcon.AnchorPoint = Vector2.new(0.5, 0)
	stateIcon.Position = UDim2.new(0.5, 0, 0, 0)
	local stateText = label({ Text = "", TextSize = 12, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 30) }, stateBox)
	local function setState(kind, text)
		if not kind then
			unspin(stateIcon)
			stateBox.Visible = false
			return
		end
		stateBox.Visible = true
		stateText.Text = text
		if kind == "loading" then
			setIcon(stateIcon, "loader-circle")
			spin(stateIcon)
		else
			unspin(stateIcon)
			setIcon(stateIcon, kind == "error" and "circle-alert" or "search-x")
		end
	end

	local overlay = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Text = "", AutoButtonColor = false, BorderSizePixel = 0, Visible = false, ZIndex = 30 }, p)
	NoTheme(overlay)
	local SW = math.min(360, WIN_W - 40)
	local sheet = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(SW, 236), BackgroundColor3 = C.bg2, Active = true }, overlay)
	round(sheet, 18)
	stroke(sheet, C.stroke, 1, 0.2)
	local dCover = frame({ Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 96), BackgroundColor3 = C.white, ClipsDescendants = true }, sheet)
	round(dCover, 12)
	NoTheme(dCover)
	local dGrad = gradient(dCover, Color3.fromHSV(0.7, 0.55, 0.95), Color3.fromHSV(0.8, 0.75, 0.5), 45)
	local dInit = label({ Text = "?", Font = Enum.Font.GothamBlack, TextSize = 34, TextColor3 = C.white, TextTransparency = 0.35, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) }, dCover)
	local dThumb = make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, ImageTransparency = 1, BorderSizePixel = 0 }, dCover)
	round(dThumb, 12)
	local dClose = make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = C.bg, BackgroundTransparency = 0.3, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 3 }, sheet)
	round(dClose, 13)
	local dCloseIc = Icon(dClose, "x", 14, C.white)
	dCloseIc.AnchorPoint = Vector2.new(0.5, 0.5)
	dCloseIc.Position = UDim2.fromScale(0.5, 0.5)
	local dTitle = label({ Text = "", Font = Enum.Font.GothamBold, TextSize = 14, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(14, 116), Size = UDim2.new(1, -28, 0, 34) }, sheet)
	local dMeta = label({ Text = "", RichText = true, TextSize = 11, TextColor3 = C.sub, Position = UDim2.fromOffset(14, 152), Size = UDim2.new(1, -28, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd }, sheet)
	local dRow = frame({ Position = UDim2.fromOffset(14, 180), Size = UDim2.new(1, -28, 0, 40), BackgroundTransparency = 1 }, sheet)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, dRow)
	local dExec = Btn(dRow, { Text = "Execute", Icon = "play", Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 1, Radius = 10, TextSize = 13 })
	local dCopy = Btn(dRow, { Text = "Copy", Icon = "copy", Style = "ghost", Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 2, Radius = 10, TextSize = 13 })
	local detailScript, dBusy = nil, false

	local function showDetail(s2)
		detailScript = s2
		local gname = gameName(s2)
		local title = s2.title or "Untitled"
		local hue = hashHue(gname .. title)
		dGrad.Color = ColorSequence.new(Color3.fromHSV(hue, 0.55, 0.95), Color3.fromHSV((hue + 0.1) % 1, 0.75, 0.5))
		dInit.Text = initials(gname)
		dThumb.Image = ""
		dThumb.ImageTransparency = 1
		queueThumb(dThumb, thumbUrl(s2))
		dTitle.Text = title
		local parts = { esc(gname) }
		if s2.verified then parts[#parts + 1] = '<font color="rgb(90,210,125)">Verified</font>' end
		if s2.key then parts[#parts + 1] = '<font color="rgb(255,190,70)">Key</font>' end
		parts[#parts + 1] = fmtNum(s2.views or 0) .. " views"
		dMeta.Text = table.concat(parts, "  |  ")
		setBtn(dExec, "Execute", "play")
		overlay.Visible = true
	end
	local function hideDetail()
		overlay.Visible = false
		detailScript = nil
	end
	bind(overlay.MouseButton1Click, hideDetail)
	bind(dClose.MouseButton1Click, hideDetail)
	bind(dCopy.Button.MouseButton1Click, function() if detailScript then copyLoadstring(detailScript) end end)
	bind(dExec.Button.MouseButton1Click, function()
		if not detailScript or dBusy then return end
		dBusy = true
		runScript(detailScript, function()
			setBtn(dExec, "Running", "loader-circle")
			spin(dExec.Icon)
		end, function(failed)
			unspin(dExec.Icon)
			setBtn(dExec, failed and "Retry" or "Executed", failed and "refresh-cw" or "check")
			task.delay(1.6, function() if dExec.Button.Parent then setBtn(dExec, "Execute", "play") end end)
			dBusy = false
		end)
	end)

	local function SbCard(s2, parent, order)
		local gname = gameName(s2)
		local title = s2.title or "Untitled"
		local card = make("TextButton", { Size = UDim2.fromOffset(cardW, cardH), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = order }, parent)

		local cover = frame({ Size = UDim2.new(1, 0, 0, coverH), BackgroundColor3 = C.white, ClipsDescendants = true }, card)
		round(cover, 12)
		NoTheme(cover)
		local hue = hashHue(gname .. title)
		gradient(cover, Color3.fromHSV(hue, 0.55, 0.95), Color3.fromHSV((hue + 0.1) % 1, 0.75, 0.5), 45)
		label({ Text = initials(gname), Font = Enum.Font.GothamBlack, TextSize = 26, TextColor3 = C.white, TextTransparency = 0.35, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) }, cover)
		local thumb = make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop, ImageTransparency = 1, BorderSizePixel = 0 }, cover)
		round(thumb, 12)
		queueThumb(thumb, thumbUrl(s2))

		local ring = frame({ Size = UDim2.new(1, 0, 0, coverH), BackgroundTransparency = 1, ZIndex = 2 }, card)
		round(ring, 12)
		local ringStroke = stroke(ring, C.red, 2, 1)

		local vpill = frame({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 0, coverH - 6), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.bg, BackgroundTransparency = 0.3, ZIndex = 3 }, card)
		round(vpill, 9)
		make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 7) }, vpill)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 3) }, vpill)
		local eye = Icon(vpill, "eye", 10, C.text)
		eye.LayoutOrder = 1
		label({ Text = fmtNum(s2.views or 0), Font = Enum.Font.GothamMedium, TextSize = 10, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2 }, vpill)

		local bx = 6
		local function badge(iconName, color)
			local b = frame({ Position = UDim2.fromOffset(bx, 6), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.bg, BackgroundTransparency = 0.3, ZIndex = 3 }, card)
			round(b, 10)
			local ic = Icon(b, iconName, 12, color)
			ic.AnchorPoint = Vector2.new(0.5, 0.5)
			ic.Position = UDim2.fromScale(0.5, 0.5)
			bx = bx + 24
		end
		if s2.verified then badge("badge-check", C.green) end
		if s2.key then badge("key", C.amber) end

		label({ Text = title, Font = Enum.Font.GothamBold, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(2, coverH + 7), Size = UDim2.new(1, -4, 0, 16) }, card)
		label({ Text = gname, TextSize = 10, TextColor3 = C.sub, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(2, coverH + 25), Size = UDim2.new(1, -4, 0, 14) }, card)

		card.MouseEnter:Connect(function() tween(ringStroke, 0.15, { Transparency = 0.1 }) end)
		card.MouseLeave:Connect(function() tween(ringStroke, 0.15, { Transparency = 1 }) end)
		card.MouseButton1Click:Connect(function() showDetail(s2) end)
		return card
	end

	local pool, seen = {}, {}
	local poolPage = 2
	local function addPool(list)
		for _, s2 in ipairs(list) do
			local key = s2._id or s2.slug or ((s2.title or "") .. gameName(s2))
			if not seen[key] then
				seen[key] = true
				pool[#pool + 1] = s2
			end
		end
	end
	local CATS = {
		{ title = "Verified creators", sub = "Scripts sourced from reputable sources", explore = "Explore all verified creators", filter = function(s2) return s2.verified end },
		{ title = "Most viewed", sub = "Popular scripts people keep running", explore = "Explore all popular scripts", sort = function(a, b) return (a.views or 0) > (b.views or 0) end },
		{ title = "No key needed", sub = "Run instantly, without a key system", explore = "Explore all no-key scripts", filter = function(s2) return not s2.key end },
		{ title = "Latest scripts", sub = "Freshly uploaded by the community", explore = "Explore all latest scripts" },
	}
	local function itemsFor(cat)
		local out = {}
		for _, s2 in ipairs(pool) do
			if not cat.filter or cat.filter(s2) then out[#out + 1] = s2 end
		end
		if cat.sort then table.sort(out, cat.sort) end
		return out
	end

	local lastReq, busy = 0, false
	local function fetchScripts(path)
		local wait = 0.7 - (os.clock() - lastReq)
		if wait > 0 then task.wait(wait) end
		lastReq = os.clock()
		local body, err = httpGet(SB_API .. path)
		if not body then return nil, "Network error: " .. tostring(err) end
		local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
		if not ok or type(data) ~= "table" or type(data.result) ~= "table" then
			return nil, "ScriptBlox sent an unexpected response"
		end
		return data.result.scripts or {}
	end
	local function busyIcon(on)
		if on then
			setIcon(goIcon, "loader-circle")
			spin(goIcon)
		else
			unspin(goIcon)
			setIcon(goIcon, "arrow-right")
		end
	end

	local view = { kind = "home" }
	local results, searchPage, searchQuery, hasMore = {}, 1, "", false

	local function clearFrames(container)
		for _, c in ipairs(container:GetChildren()) do
			if c:IsA("GuiObject") and c.Name ~= "Keep" then c:Destroy() end
		end
	end

	local function showHomeView()
		view = { kind = "home" }
		gridHead.Visible, grid.Visible, home.Visible = false, false, true
	end
	local function showGridView(titleText, subText)
		gridTitle.Text, gridSub.Text = titleText, subText
		gridHead.Visible, grid.Visible, home.Visible = true, true, false
	end

	local renderGrid
	local function loadMore()
		if busy then return end
		busy = true
		busyIcon(true)
		task.spawn(function()
			local list, err
			if view.kind == "search" then
				list, err = fetchScripts("/search?q=" .. HttpService:UrlEncode(searchQuery) .. "&max=20&page=" .. (searchPage + 1) .. "&mode=free")
			else
				list, err = fetchScripts("/fetch?max=20&page=" .. (poolPage + 1) .. "&mode=free")
			end
			if not alive then return end
			busy = false
			busyIcon(false)
			if not list then
				Notify({ Title = "ScriptBlox", Text = err, Type = "error", Duration = 5 })
				return
			end
			if view.kind == "search" then
				searchPage = searchPage + 1
				for _, s2 in ipairs(list) do results[#results + 1] = s2 end
				hasMore = #list >= 20 and #results < 120
			else
				poolPage = poolPage + 1
				addPool(list)
				hasMore = #list >= 20 and poolPage < 8
			end
			renderGrid()
		end)
	end

	renderGrid = function()
		clearFrames(grid)
		local items = (view.kind == "search") and results or itemsFor(view.cat)
		for i, s2 in ipairs(items) do SbCard(s2, grid, i) end
		if hasMore then
			local tile = make("TextButton", { Size = UDim2.fromOffset(cardW, cardH), BackgroundColor3 = C.card, Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = 1000000 }, grid)
			round(tile, 12)
			stroke(tile, C.stroke, 1, 0.4)
			local ic = Icon(tile, "chevron-down", 22, C.redHi)
			ic.AnchorPoint = Vector2.new(0.5, 0.5)
			ic.Position = UDim2.new(0.5, 0, 0.5, -10)
			label({ Text = "Load more", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 6), Size = UDim2.new(1, 0, 0, 14) }, tile)
			tile.MouseButton1Click:Connect(loadMore)
		end
		if #items == 0 then setState("empty", "No scripts found") else setState(nil) end
	end

	local function openCat(cat)
		view = { kind = "cat", cat = cat }
		hasMore = poolPage < 8
		showGridView(cat.title, cat.sub)
		renderGrid()
	end

	local function renderHome()
		clearFrames(home)
		local order = 0
		for _, cat in ipairs(CATS) do
			local items = itemsFor(cat)
			if #items > 0 then
				order = order + 1
				local sec = frame({ Size = UDim2.new(1, 0, 0, 44 + cardH + 10), BackgroundTransparency = 1, LayoutOrder = order }, home)
				label({ Text = cat.title, Font = Enum.Font.GothamBold, TextSize = 16, Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -150, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd }, sec)
				label({ Text = cat.sub, TextSize = 11, TextColor3 = C.sub, Position = UDim2.fromOffset(2, 21), Size = UDim2.new(1, -150, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd }, sec)
				local link = make("TextButton", {
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
					BackgroundTransparency = 1, Text = (WIN_W >= 560 and cat.explore or "Explore all") .. "  >", TextColor3 = C.redHi,
					Font = Enum.Font.GothamMedium, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0,
				}, sec)
				link.MouseButton1Click:Connect(function() openCat(cat) end)

				local row = make("ScrollingFrame", {
					Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, cardH + 10), BackgroundTransparency = 1, BorderSizePixel = 0,
					ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X,
				}, sec)
				make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10) }, row)
				for i = 1, math.min(#items, 14) do SbCard(items[i], row, i) end
			end
		end
		if order == 0 then setState("empty", "No scripts found") else setState(nil) end
	end

	local function goHome()
		showHomeView()
		if #pool > 0 then renderHome() end
	end

	local function loadHome()
		if busy then return end
		busy = true
		busyIcon(true)
		setState("loading", "Loading scripts...")
		task.spawn(function()
			local firstErr
			for _, path in ipairs({ "/fetch?max=20&page=1&mode=free&verified=1", "/fetch?max=20&page=1&mode=free", "/fetch?max=20&page=2&mode=free" }) do
				local list, err = fetchScripts(path)
				if list then addPool(list) else firstErr = firstErr or err end
			end
			if not alive then return end
			busy = false
			busyIcon(false)
			if #pool == 0 then
				setState("error", firstErr or "No scripts found")
				Notify({ Title = "ScriptBlox", Text = firstErr or "No scripts found", Type = "error", Duration = 5 })
				return
			end
			renderHome()
		end)
	end

	local function doSearch(query)
		query = trim(query)
		if busy then return end
		if query == "" then
			if view.kind ~= "home" then goHome() elseif #pool == 0 then loadHome() end
			return
		end
		busy = true
		busyIcon(true)
		searchQuery, searchPage, results = query, 1, {}
		view = { kind = "search" }
		showGridView('Results for "' .. query .. '"', "From ScriptBlox")
		clearFrames(grid)
		setState("loading", 'Searching for "' .. query .. '"...')
		task.spawn(function()
			local list, err = fetchScripts("/search?q=" .. HttpService:UrlEncode(query) .. "&max=20&page=1&mode=free")
			if not alive then return end
			busy = false
			busyIcon(false)
			if not list then
				setState("error", err)
				Notify({ Title = "ScriptBlox", Text = err, Type = "error", Duration = 5 })
				return
			end
			results = list
			hasMore = #list >= 20
			renderGrid()
		end)
	end

	bind(goBtn.MouseButton1Click, function() doSearch(box.Text) end)
	bind(box.FocusLost, function(enter) if enter then doSearch(box.Text) end end)
	bind(backBtn.MouseButton1Click, function()
		setState(nil)
		goHome()
	end)

	local opened = false
	sbOnOpen = function()
		if opened then return end
		opened = true
		loadHome()
	end
end)

safeBuild("Updates", function()
	local p = newPage("Updates")
	Header(p, "Update log", "What changed in Shadow")
	local list = List(p, UDim2.fromOffset(14, 58), UDim2.new(1, -28, 1, -64))
	local TAGS = {
		new      = { "circle-plus", C.green },
		improved = { "sparkles", C.blue },
		fix      = { "wrench", C.amber },
		removed  = { "trash", C.red },
	}
	for i, rel in ipairs(CHANGELOG) do
		local block = frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.card, LayoutOrder = i }, list)
		round(block, 10)
		stroke(block, C.stroke, 1, 0.4)
		make("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, block)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, block)

		local head = frame({ Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1 }, block)
		label({ Text = "v" .. rel.version, Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.redHi, Size = UDim2.fromOffset(60, 18) }, head)
		label({ Text = rel.date, TextSize = 11, TextColor3 = C.sub, Position = UDim2.fromOffset(62, 0), Size = UDim2.fromOffset(80, 18) }, head)
		if i == 1 then
			local lt = frame({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(46, 16), BackgroundColor3 = C.green, BackgroundTransparency = 0.8 }, head)
			round(lt, 8)
			label({ Text = "LATEST", Font = Enum.Font.GothamBold, TextSize = 9, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) }, lt)
		end
		label({ Text = rel.title, Font = Enum.Font.GothamMedium, TextSize = 12, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2 }, block)

		for j, ch in ipairs(rel.changes) do
			local tag = TAGS[ch[1]] or TAGS.new
			local row = frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 + j }, block)
			local ic = Icon(row, tag[1], 14, tag[2])
			ic.Position = UDim2.fromOffset(0, 1)
			label({
				Text = ch[2], TextSize = 12, TextColor3 = C.sub, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
				Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			}, row)
		end
	end
end)

safeBuild("Console", function()
	local p = newPage("Console")
	Header(p, "Console", "Live output from the Roblox developer console")
	local LogService = game:GetService("LogService")

	local clearBtn = IconBtn(p, "trash", 16, { Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), BackgroundColor3 = C.card })
	local copyBtn = IconBtn(p, "copy", 16, { Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -50, 0, 12), BackgroundColor3 = C.card })

	local box = frame({ Position = UDim2.fromOffset(14, 58), Size = UDim2.new(1, -28, 1, -70), BackgroundColor3 = C.bg }, p)
	round(box, 12)
	stroke(box, C.stroke, 1, 0.35)
	local scroll = make("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 1, -12), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.red, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, box)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, scroll)
	NoTheme(scroll)

	local COLORS = {
		[Enum.MessageType.MessageOutput] = Color3.fromRGB(225, 220, 230),
		[Enum.MessageType.MessageInfo] = Color3.fromRGB(110, 170, 255),
		[Enum.MessageType.MessageWarning] = Color3.fromRGB(255, 190, 70),
		[Enum.MessageType.MessageError] = Color3.fromRGB(255, 95, 95),
	}
	local lines, texts, order, scrollQueued = {}, {}, 0, false
	local function addLine(msg, mtype, ts)
		order = order + 1
		local text = os.date("%H:%M:%S", ts or os.time()) .. "  " .. tostring(msg):sub(1, 1200)
		local atBottom = scroll.CanvasPosition.Y + scroll.AbsoluteWindowSize.Y >= scroll.AbsoluteCanvasSize.Y - 12
		lines[#lines + 1] = label({
			Text = text, Font = Enum.Font.Code, TextSize = 11, TextColor3 = COLORS[mtype] or COLORS[Enum.MessageType.MessageOutput],
			TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y,
			Size = UDim2.new(1, 0, 0, 0), LayoutOrder = order,
		}, scroll)
		texts[#texts + 1] = text
		if #lines > 300 then
			table.remove(lines, 1):Destroy()
			table.remove(texts, 1)
		end
		if atBottom and not scrollQueued then
			scrollQueued = true
			task.delay(0.05, function()
				scrollQueued = false
				if scroll.Parent then scroll.CanvasPosition = Vector2.new(0, 1e6) end
			end)
		end
	end

	local okH, hist = pcall(function() return LogService:GetLogHistory() end)
	if okH and type(hist) == "table" then
		for i = math.max(1, #hist - 150), #hist do
			local h = hist[i]
			addLine(h.message, h.messageType, h.timestamp)
		end
	end
	bind(LogService.MessageOut, function(msg, mtype) addLine(msg, mtype) end)

	bind(clearBtn.MouseButton1Click, function()
		for _, l in ipairs(lines) do l:Destroy() end
		lines, texts = {}, {}
	end)
	bind(copyBtn.MouseButton1Click, function()
		if #texts == 0 then
			Notify({ Title = "Console is empty", Text = "Nothing to copy.", Type = "warn", Duration = 2.5 })
		elseif copyText(table.concat(texts, "\n")) then
			Notify({ Title = "Copied", Text = "Console output copied to clipboard.", Type = "success", Duration = 2.5 })
		else
			Notify({ Title = "Can't copy", Text = "Your executor has no clipboard function.", Type = "warn" })
		end
	end)
end)

safeBuild("Settings", function()
	local p = newPage("Settings")
	Header(p, "Settings", "Customize how the UI looks and behaves.")
	local list = List(p, UDim2.fromOffset(14, 58), UDim2.new(1, -28, 1, -64))
	list:FindFirstChildOfClass("UIListLayout").Padding = UDim.new(0, 0)
	local order = 0

	local function Row(iconName, titleText, descText)
		order = order + 1
		local card = frame({ Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1, LayoutOrder = order }, list)
		frame({ Size = UDim2.new(1, 0, 0, 1), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.stroke, BackgroundTransparency = 0.5 }, card)
		label({ Text = titleText, Font = Enum.Font.GothamBold, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(2, 11), Size = UDim2.new(1, -2 - 150, 0, 18) }, card)
		label({ Text = descText, TextSize = 11, TextColor3 = C.sub, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(2, 31), Size = UDim2.new(1, -2 - 150, 0, 16) }, card)
		return card
	end

	local function Switch(parent, initial, onChange)
		local on = initial
		local function OFF() return P(56, 44, 52) end
		local b = make("TextButton", {
			Size = UDim2.fromOffset(40, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
			BackgroundColor3 = on and C.red or OFF(), Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		}, parent)
		round(b, 11)
		local knob = frame({ Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0, 0.5), Position = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = C.white }, b)
		round(knob, 8)
		bind(b.MouseButton1Click, function()
			on = not on
			tween(b, 0.18, { BackgroundColor3 = on and C.red or OFF() })
			tween(knob, 0.2, { Position = on and UDim2.new(1, -19, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, Enum.EasingStyle.Back)
			onChange(on)
		end)
		return b
	end

	local function Segmented(parent, options, selected, onChange)
		local wrap = frame({ Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), BackgroundColor3 = C.bg }, parent)
		round(wrap, 8)
		make("UIPadding", { PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2) }, wrap)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2) }, wrap)
		local items = {}
		local function paint(sel)
			for id, it in pairs(items) do
				local on = (id == sel)
				tween(it.btn, 0.15, { BackgroundTransparency = on and 0.1 or 1 })
				if it.ic then tintIcon(it.ic, on and C.white or C.sub) end
				if it.lb then it.lb.TextColor3 = on and C.white or C.sub end
			end
		end
		for i, o in ipairs(options) do
			local btn = make("TextButton", { Size = UDim2.fromOffset(o.width or 30, 24), BackgroundColor3 = C.red2, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = i }, wrap)
			round(btn, 6)
			local it = { btn = btn }
			if o.icon then
				it.ic = Icon(btn, o.icon, 14, C.sub)
				it.ic.AnchorPoint = Vector2.new(0.5, 0.5)
				it.ic.Position = UDim2.fromScale(0.5, 0.5)
			else
				it.lb = label({ Text = o.text, Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) }, btn)
			end
			items[o.id] = it
			bind(btn.MouseButton1Click, function()
				paint(o.id)
				onChange(o.id)
			end)
		end
		paint(selected)
		return wrap
	end

	local function SmallBtn(parent, text, iconName, style, width)
		return Btn(parent, { Text = text, Icon = iconName, Style = style, Size = UDim2.fromOffset(width or 96, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Radius = 8 })
	end

	do
		local row = Row("scan", "UI scale", "Adjust the visual scale of UI elements.")
		row.Size = UDim2.new(1, 0, 0, 146)
		local availW = WIN_W - 28 - 8
		local cw = math.floor(math.min(96, (availW - 16) / 3))
		local opts = {
			{ v = 1,    text = "100%", frac = 0.55 },
			{ v = 1.25, text = "125%", frac = 0.68 },
			{ v = 1.5,  text = "150%", frac = 0.82 },
		}
		local function paintScale()
			for _, o in ipairs(opts) do
				local on = math.abs(SETTINGS.UIScale - o.v) < 0.01
				tween(o.stroke, 0.15, { Transparency = on and 0 or 1 })
				o.lbl.TextColor3 = on and C.text or C.sub
				o.lbl.Font = on and Enum.Font.GothamBold or Enum.Font.Gotham
			end
		end
		local dots = { Color3.fromRGB(255, 96, 92), Color3.fromRGB(255, 189, 68), Color3.fromRGB(39, 201, 63) }
		for i, o in ipairs(opts) do
			local x = 2 + (i - 1) * (cw + 8)
			local b = make("TextButton", { Position = UDim2.fromOffset(x, 62), Size = UDim2.fromOffset(cw, 58), BackgroundColor3 = C.white, Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, row)
			round(b, 10)
			gradient(b, C.redHi, C.red2, 45)
			o.stroke = stroke(b, C.white, 2, 1)
			local mw = frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(o.frac, 0, 0.72, 0), BackgroundColor3 = C.bg }, b)
			round(mw, 6)
			for d = 1, 3 do
				local dot = frame({ Position = UDim2.fromOffset(5 + (d - 1) * 8, 5), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = dots[d] }, mw)
				round(dot, 3)
			end
			o.lbl = label({ Text = o.text, TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x, 123), Size = UDim2.fromOffset(cw, 14) }, row)
			bind(b.MouseButton1Click, function()
				SETTINGS.UIScale = o.v
				saveSettings()
				applyUIScale(true, false)
				paintScale()
			end)
		end
		paintScale()
	end

	do
		local row = Row("square", "Corner radius", "Align the UI with your display's corners.")
		local lo, hi = 0, 28
		local hit = make("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(150, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, row)
		local track = frame({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = C.card }, hit)
		round(track, 3)
		local f0 = math.clamp((SETTINGS.CornerRadius - lo) / (hi - lo), 0, 1)
		local fill = frame({ Size = UDim2.new(f0, 0, 1, 0), BackgroundColor3 = C.red }, track)
		round(fill, 3)
		local knob = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(f0, 0, 0.5, 0), Size = UDim2.fromOffset(9, 18), BackgroundColor3 = C.white }, hit)
		round(knob, 4)
		local dragging = false
		local function setFromX(x, final)
			local f = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			local v = math.floor(lo + (hi - lo) * f + 0.5)
			knob.Position = UDim2.new(f, 0, 0.5, 0)
			fill.Size = UDim2.new(f, 0, 1, 0)
			SETTINGS.CornerRadius = v
			applyCorner(v)
			if final then saveSettings() end
		end
		bind(hit.InputBegan, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setFromX(input.Position.X, false)
				local c
				c = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						c:Disconnect()
						dragging = false
						saveSettings()
					end
				end)
			end
		end)
		bind(UIS.InputChanged, function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setFromX(input.Position.X, false)
			end
		end)
	end

	Switch(Row("square-dashed", "Window borders", "Whether the window uses a glowing border."), SETTINGS.WindowBorders, function(on)
		SETTINGS.WindowBorders = on
		applyBorders()
		saveSettings()
	end)

	Switch(Row("scan", "Screen glow", "Gradient glow around the edges of the screen."), SETTINGS.ScreenGlow, function(on)
		SETTINGS.ScreenGlow = on
		applyScreenGlow()
		saveSettings()
	end)

	Switch(Row("terminal", "Console", "Show the Console tab with live Roblox output."), SETTINGS.Console, function(on)
		SETTINGS.Console = on
		STATE.applyConsole()
		saveSettings()
		if on then Notify({ Title = "Console enabled", Text = "A Console tab now appears in the side rail.", Type = "success", Icon = "terminal", Duration = 3 }) end
	end)

	do
		order = order + 1
		local card = frame({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, list)
		make("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 6) }, card)
		frame({ Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.stroke, BackgroundTransparency = 0.5, LayoutOrder = 99 }, card)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, card)
		label({ Text = "Theme", Font = Enum.Font.GothamBold, TextSize = 14, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1 }, card)
		local desc = label({ Text = "", TextSize = 11, TextColor3 = C.sub, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 }, card)

		local count = #THEMES + 1
		local availW = WIN_W - 28 - 8
		local perRow = math.max(1, math.floor((availW + 8) / 38))
		local rows = math.ceil(count / perRow)
		local swatchWrap = frame({ Size = UDim2.new(1, 0, 0, rows * 38 - 8), BackgroundTransparency = 1, LayoutOrder = 3 }, card)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, swatchWrap)

		local swatches = {}
		local function currentLabel() return "Current: " .. SETTINGS.Theme end
		desc.Text = currentLabel()
		local function paintSwatches()
			for name, sw in pairs(swatches) do
				local on = (name == SETTINGS.Theme)
				tween(sw.stroke, 0.15, { Transparency = on and 0 or 1 })
			end
			desc.Text = currentLabel()
		end
		local function makeSwatch(name, color, order_)
			local b = make("TextButton", { Size = UDim2.fromOffset(30, 30), BackgroundColor3 = color, Text = "", AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = order_ }, swatchWrap)
			round(b, 15)
			NoTheme(b)
			local st = stroke(b, C.white, 2, 1)
			swatches[name] = { btn = b, stroke = st }
			bind(b.MouseEnter, function() desc.Text = name end)
			bind(b.MouseLeave, function() desc.Text = currentLabel() end)
			return b
		end

		local function setTheme(name, silent)
			SETTINGS.Theme = name
			applyTheme(themeParams(name))
			saveSettings()
			paintSwatches()
			if not silent then
				Notify({ Title = "Theme applied", Text = name, Type = "success", Icon = "palette", Duration = 2.5 })
			end
		end

		for i, t in ipairs(THEMES) do
			local preview = xform(Color3.fromRGB(255, 50, 60), { hue = t.hue - BASE_HUE, sat = t.sat, val = t.val })
			local b = makeSwatch(t.name, preview, i)
			bind(b.MouseButton1Click, function() setTheme(t.name) end)
		end
		do
			local b = makeSwatch("Custom", C.white, count)
			make("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0.9, 1)), ColorSequenceKeypoint.new(0.25, Color3.fromHSV(0.25, 0.9, 1)),
					ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 0.9, 1)), ColorSequenceKeypoint.new(0.75, Color3.fromHSV(0.75, 0.9, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 0.9, 1)),
				}),
				Rotation = 45,
			}, b)
			local pen = Icon(b, "pencil", 14, C.white)
			pen.AnchorPoint = Vector2.new(0.5, 0.5)
			pen.Position = UDim2.fromScale(0.5, 0.5)
			bind(b.MouseButton1Click, function() setTheme("Custom") end)
		end

		local custom = frame({ Size = UDim2.new(1, 0, 0, 78), BackgroundTransparency = 1, LayoutOrder = 4 }, card)
		local lastApply = 0
		local function Slider(y, text, lo, hi, value, key, rainbow)
			label({ Text = text, TextSize = 11, TextColor3 = C.sub, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(70, 24) }, custom)
			local hit = make("TextButton", { Position = UDim2.new(0, 76, 0, y), Size = UDim2.new(1, -76, 0, 24), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, custom)
			local track = frame({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.bg }, hit)
			round(track, 3)
			local f0 = math.clamp((value - lo) / (hi - lo), 0, 1)
			local fill
			if rainbow then
				track.BackgroundColor3 = C.white
				make("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)), ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
						ColorSequenceKeypoint.new(0.34, Color3.fromHSV(0.34, 1, 1)), ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
						ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)), ColorSequenceKeypoint.new(0.84, Color3.fromHSV(0.84, 1, 1)),
						ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
					}),
				}, track)
				NoTheme(track)
			else
				fill = frame({ Size = UDim2.new(f0, 0, 1, 0), BackgroundColor3 = C.red }, track)
				round(fill, 3)
			end
			local knob = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(f0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = C.white }, hit)
			round(knob, 7)
			stroke(knob, C.red, 2, 0)

			local dragging, cur = false, value
			local function setFromX(x, final)
				local ap, as = track.AbsolutePosition.X, track.AbsoluteSize.X
				local f = math.clamp((x - ap) / math.max(as, 1), 0, 1)
				cur = lo + (hi - lo) * f
				knob.Position = UDim2.new(f, 0, 0.5, 0)
				if fill then fill.Size = UDim2.new(f, 0, 1, 0) end
				SETTINGS[key] = cur
				SETTINGS.Theme = "Custom"
				if final or os.clock() - lastApply > 0.06 then
					lastApply = os.clock()
					applyTheme(themeParams("Custom"))
				end
			end
			bind(hit.InputBegan, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					setFromX(input.Position.X, false)
					local c
					c = input.Changed:Connect(function()
						if input.UserInputState == Enum.UserInputState.End then
							c:Disconnect()
							dragging = false
							setFromX(knob.AbsolutePosition.X + knob.AbsoluteSize.X / 2, true)
							saveSettings()
							paintSwatches()
						end
					end)
				end
			end)
			bind(UIS.InputChanged, function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					setFromX(input.Position.X, false)
				end
			end)
		end
		Slider(0, "Hue", 0, 360, SETTINGS.CustomHue, "CustomHue", true)
		Slider(26, "Saturation", 0.2, 1, SETTINGS.CustomSat, "CustomSat", false)
		Slider(52, "Brightness", 0.6, 1, SETTINGS.CustomVal, "CustomVal", false)

		paintSwatches()
	end

	Switch(Row("bell", "Notifications", "Show toast pop-ups"), SETTINGS.Notifications, function(on)
		if on then
			SETTINGS.Notifications = true
			Notify({ Title = "Notifications on", Text = "You will see pop-ups again.", Type = "success", Duration = 2.5 })
		else
			Notify({ Title = "Notifications off", Type = "info", Duration = 2 })
			SETTINGS.Notifications = false
		end
		saveSettings()
	end)

	Segmented(Row("layout-dashboard", "Notification position", "Where toasts appear"), {
		{ id = "TopLeft", icon = "arrow-up-left" }, { id = "TopRight", icon = "arrow-up-right" },
		{ id = "BottomLeft", icon = "arrow-down-left" }, { id = "BottomRight", icon = "arrow-down-right" },
	}, SETTINGS.NotifyPosition, function(id)
		SETTINGS.NotifyPosition = id
		applyNotifPosition(id)
		saveSettings()
		Notify({ Title = "Position updated", Text = "Notifications will appear here.", Type = "info", Duration = 2.5, Force = true })
	end)

	Segmented(Row("timer", "Notification time", "How long toasts stay"), {
		{ id = "Short", text = "Short", width = 46 }, { id = "Normal", text = "Normal", width = 52 }, { id = "Long", text = "Long", width = 44 },
	}, SETTINGS.NotifyDuration, function(id)
		SETTINGS.NotifyDuration = id
		saveSettings()
	end)

	Switch(Row("circle-dot", "Floating button", "Shown while the UI is hidden: tap to open, hold for the tab bar"), SETTINGS.FloatButton, function(on)
		SETTINGS.FloatButton = on
		saveSettings()
		if floatApply then floatApply() end
	end)

	Switch(Row("key", "Remember key", "Auto sign-in with your saved key"), SETTINGS.RememberKey, function(on)
		SETTINGS.RememberKey = on
		CONFIG.Key.Remember = on
		saveSettings()
	end)

	do
		local row = Row("log-out", "Forget saved key", "Ask for the key again next launch")
		local btn = SmallBtn(row, "Forget", "trash", "ghost", 92)
		bind(btn.Button.MouseButton1Click, function()
			fileWrite("key.txt", "")
			Notify({ Title = "Saved key removed", Text = "You'll be asked for your key next time.", Type = "success", Icon = "trash" })
		end)
	end

	do
		local row = Row("bell-ring", "Test notifications", "Preview every toast style")
		local btn = SmallBtn(row, "Test", "play", "primary", 80)
		bind(btn.Button.MouseButton1Click, function()
			Notify({ Title = "Success", Text = "Everything worked as expected.", Type = "success", Force = true })
			task.wait(0.2)
			Notify({ Title = "Heads up", Text = "This is a warning with a longer message so you can see how wrapping looks.", Type = "warn", Force = true })
			task.wait(0.2)
			Notify({ Title = "Error", Text = "Something went wrong.", Type = "error", Force = true })
			task.wait(0.2)
			Notify({ Title = "Info", Type = "info", Force = true })
		end)
	end

	do
		local row = Row("message-circle", "Discord", "Copy the invite link")
		local btn = SmallBtn(row, "Copy", "copy", "blurple", 84)
		bind(btn.Button.MouseButton1Click, function()
			if copyText(CONFIG.Discord) then
				Notify({ Title = "Discord invite copied", Text = CONFIG.Discord, Type = "success", Icon = "message-circle", Duration = 3 })
			else
				Notify({ Title = "Join our Discord", Text = CONFIG.Discord, Type = "info", Icon = "message-circle", Duration = 6 })
			end
		end)
	end

	label({ Text = "Shadow v" .. VERSION .. "  |  Made by " .. CONFIG.Credits, TextSize = 10, TextColor3 = P(110, 95, 104), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 100 }, list)
end)

local KEYCFG = CONFIG.Key

local function normalizeKey(k)
	k = tostring(k or "")
	for _, bad in ipairs({ "\226\128\139", "\226\128\140", "\226\128\141", "\239\187\191" }) do
		k = k:gsub(bad, "")
	end
	return (k:gsub("[%s\"'`]+", ""):lower())
end

-- signed keys from the Discord bot ----------------------------------------
-- SF-AAAA-BBBB-CCCC-SSSS never expires, ST-EEEE-AAAA-BBBB-SSSS works until the UTC
-- day in EEEE. SSSS is a checksum with the secret, so keys work offline.
-- returns "valid", expiry-timestamp-or-nil  |  "expired"  |  nil (not a signed key)
local signedKeyState
do
	local KEY_ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	local kbxor = (bit32 and bit32.bxor) or function(a, b)
		local r, bit = 0, 1
		while a > 0 or b > 0 do
			if (a % 2) ~= (b % 2) then r = r + bit end
			a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
		end
		return r
	end
	local function kmul32(a, b)
		local high, low = math.floor(a / 65536), a % 65536
		return (((high * b) % 65536) * 65536 + low * b) % 4294967296
	end
	local function kfnv(text)
		local h = 2166136261
		for i = 1, #text do h = kmul32(kbxor(h, text:byte(i)), 16777619) end
		return h
	end
	local function kencode(h, len)
		local out = ""
		for _ = 1, len do
			local i = h % 32
			out = out .. KEY_ALPHA:sub(i + 1, i + 1)
			h = math.floor(h / 32)
		end
		return out
	end
	local function kdecode(text)
		local n = 0
		for i = #text, 1, -1 do
			local idx = KEY_ALPHA:find(text:sub(i, i), 1, true)
			if not idx then return nil end
			n = n * 32 + (idx - 1)
		end
		return n
	end

	signedKeyState = function(input)
		local secret = KEYCFG.Secret
		if not secret or secret == "" then return nil end
		local key = normalizeKey(input):upper()
		local B = "([A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9])"
		local a, b, c, sum = key:match("^SF%-" .. B .. "%-" .. B .. "%-" .. B .. "%-" .. B .. "$")
		if a then
			return kencode(kfnv(a .. b .. c .. secret), 4) == sum and "valid" or nil, nil
		end
		local exp, x, y, sum2 = key:match("^ST%-" .. B .. "%-" .. B .. "%-" .. B .. "%-" .. B .. "$")
		if exp and kencode(kfnv("T" .. exp .. x .. y .. secret), 4) == sum2 then
			local lastDay = kdecode(exp)
			if not lastDay then return nil end
			if math.floor(os.time() / 86400) <= lastDay then
				return "valid", (lastDay + 1) * 86400 - 1
			end
			return "expired"
		end
		return nil
	end
end

local function parseKeys(body)
	local list = {}
	for line in (tostring(body):gsub("^\239\187\191", "")):gmatch("[^\r\n]+") do
		line = trim(line)
		if line ~= "" and line:sub(1, 2) ~= "--" and line:sub(1, 1) ~= "#" then
			local k, d = line:match("^(.-)%s*|%s*(%d+%-%d+%-%d+)$")
			if not k then k = line end
			local exp
			if d then
				local y, m, dd = d:match("(%d+)-(%d+)-(%d+)")
				exp = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 23, min = 59, sec = 59 })
			end
			list[#list + 1] = { key = normalizeKey(k), expires = exp }
		end
	end
	return list
end

local function activationExpiry(key)
	local days = KEYCFG.DefaultDays or 0
	if days <= 0 then return nil end
	local data = {}
	local raw = fileRead("activations.json")
	if raw then
		local ok, d = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and type(d) == "table" then data = d end
	end
	local t = tonumber(data[key])
	if not t then
		t = os.time()
		data[key] = t
		fileWrite("activations.json", HttpService:JSONEncode(data))
	end
	return t + days * 86400
end

local function validateKey(input)
	local key = normalizeKey(input)
	if key == "" then return false, "Enter your key first" end
	local signed, signedExp = signedKeyState(input)
	if signed == "valid" then return true, signedExp end
	if signed == "expired" then return false, "This key has expired" end
	local entries = {}
	for _, e in ipairs(parseKeys(table.concat(KEYCFG.Keys or {}, "\n"))) do entries[#entries + 1] = e end
	local remoteFailed = false
	if KEYCFG.RemoteUrl and KEYCFG.RemoteUrl ~= "" then
		local sep = KEYCFG.RemoteUrl:find("?", 1, true) and "&" or "?"
		local body = httpGet(KEYCFG.RemoteUrl .. sep .. "t=" .. os.time())
		if body then
			fileWrite("keys_cache.txt", os.time() .. "\n" .. body)
			for _, e in ipairs(parseKeys(body)) do entries[#entries + 1] = e end
		else
			local raw = fileRead("keys_cache.txt")
			local ts, rest = nil, nil
			if raw then ts, rest = raw:match("^(%d+)\n(.*)$") end
			if ts and os.time() - tonumber(ts) <= (KEYCFG.OfflineHours or 48) * 3600 then
				for _, e in ipairs(parseKeys(rest)) do entries[#entries + 1] = e end
			else
				remoteFailed = true
			end
		end
	end
	for _, e in ipairs(entries) do
		if e.key == key then
			local exp = e.expires or activationExpiry(key)
			if exp and os.time() > exp then return false, "This key has expired" end
			return true, exp
		end
	end
	if remoteFailed then return false, "Couldn't reach the key server", true end
	return false, "Invalid key"
end

STATE.restoreKey = function()
	local saved = fileRead("key.txt")
	if not saved or saved == "" then return false, "No saved key. Enter it again with Remember key on." end
	local ok, exp = validateKey(saved)
	if ok then
		if STATE.keyInfo then STATE.keyInfo(exp) end
		return true
	end
	return false, exp
end

local function unlockHub()
	if unlocked then return end
	unlocked = true
	if STATE.dismissKey then STATE.dismissKey() end
	if STATE.reveal then STATE.reveal() end
	showPage("Home")
	if unread then
		task.delay(0.9, function()
			Notify({ Title = "What's new in v" .. VERSION, Text = "Open the Updates tab to see what changed.", Type = "info", Icon = "sparkles", Duration = 5 })
		end)
	end
end

if KEYCFG.Enabled then
	local keyOk = safeBuild("Key", function()
		local kg = Instance.new("ScreenGui")
		kg.Name = "ShadowKey"
		kg.ResetOnSpawn = false
		kg.IgnoreGuiInset = true
		kg.DisplayOrder = 998
		kg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		pcall(function() kg.ScreenInsets = Enum.ScreenInsets.None end)
		kg.Parent = parentGui
		STATE.keyGui = kg

		local cam2 = workspace.CurrentCamera
		local vs2 = (cam2 and cam2.ViewportSize) or Vector2.new(1280, 720)
		local KW = math.clamp(vs2.X - 32, 280, 360)
		local KH = 262
		local FW = KW - 48

		local holder = make("Frame", { Name = "KeyRoot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(KW, KH), BackgroundTransparency = 1 }, kg)
		local kScale = make("UIScale", { Scale = 0.9 }, holder)

		local kHalo = make("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 120, 1, 120),
			BackgroundTransparency = 1, BorderSizePixel = 0, Image = "rbxassetid://5554236805", ImageColor3 = C.white,
			ImageTransparency = 1, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(23, 23, 277, 277), SliceScale = 2.6, ZIndex = 0,
		}, holder)
		local kHaloGrad = make("UIGradient", { Color = glowColors(), Rotation = 45 }, kHalo)

		local card = make("CanvasGroup", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BorderSizePixel = 0, GroupTransparency = 1 }, holder)
		round(card, 18)
		local kbg = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.white, BackgroundTransparency = 0.04, ZIndex = 0 }, card)
		round(kbg, 18)
		gradient(kbg, P(26, 22, 28), P(12, 10, 14), 90)
		local kBorder = frame({ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 60, Interactable = false }, card)
		round(kBorder, 18)
		local kBorderStroke = stroke(kBorder, C.white, 1.25, 0.2)
		local kBorderGrad = make("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, C.red), ColorSequenceKeypoint.new(0.5, P(40, 10, 15)), ColorSequenceKeypoint.new(1, C.red),
			}),
		}, kBorderStroke)
		bind(RS.RenderStepped, function()
			if not kg.Parent then return end
			local now = os.clock()
			kHaloGrad.Rotation = (45 + now * 22) % 360
			kBorderGrad.Rotation = (now * 70) % 360
		end)

		local form = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(FW, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, card)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, form)

		local lockCircle = frame({ Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.white, LayoutOrder = 1 }, form)
		round(lockCircle, 20)
		gradient(lockCircle, C.redHi, C.red2, 90)
		stroke(lockCircle, C.redHi, 3, 0.6)
		local lockIcon = Icon(lockCircle, "lock", 20, C.white)
		lockIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		lockIcon.Position = UDim2.fromScale(0.5, 0.5)

		label({ Text = "Key Required", Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 2 }, form)
		label({ Text = "Enter your key to unlock Shadow.", TextSize = 12, TextColor3 = C.sub, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 3 }, form)

		local inputWrap = frame({ Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = 4 }, form)
		local inputRow = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.card }, inputWrap)
		round(inputRow, 10)
		local irs = stroke(inputRow, C.stroke, 1, 0.3)
		local kIcon = Icon(inputRow, "key", 16, C.sub)
		kIcon.Position = UDim2.fromOffset(12, 11)
		local keyBox = make("TextBox", {
			Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -48, 1, 0), BackgroundTransparency = 1,
			Text = "", PlaceholderText = "Paste your key here", PlaceholderColor3 = P(110, 95, 104),
			TextColor3 = C.text, Font = Enum.Font.Code, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false, ClipsDescendants = true,
		}, inputRow)
		local getClip = getclipboard or fromclipboard or (Clipboard and Clipboard.get)
		if getClip then
			keyBox.Size = UDim2.new(1, -82, 1, 0)
			local pasteBtn = IconBtn(inputRow, "clipboard", 15, { Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), BackgroundColor3 = C.bg })
			bind(pasteBtn.MouseButton1Click, function()
				local okC, txt = pcall(getClip)
				if okC and type(txt) == "string" and trim(txt) ~= "" then
					keyBox.Text = trim(txt)
				else
					Notify({ Title = "Clipboard empty", Text = "Copy your key first, then tap paste.", Type = "warn", Duration = 2.5 })
				end
			end)
		end
		bind(keyBox.Focused, function() tween(irs, 0.15, { Color = C.red, Transparency = 0.1 }) end)
		bind(keyBox.FocusLost, function() tween(irs, 0.15, { Color = C.stroke, Transparency = 0.3 }) end)

		local btnRow = frame({ Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = 5 }, form)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, btnRow)
		local verifyBtn = Btn(btnRow, { Text = "Verify Key", Icon = "shield-check", Size = UDim2.fromOffset(FW - 112, 36), LayoutOrder = 1, Radius = 10, TextSize = 13 })
		local getBtn = Btn(btnRow, { Text = "Get Key", Icon = "external-link", Style = "ghost", Size = UDim2.fromOffset(104, 36), LayoutOrder = 2, Radius = 10, TextSize = 13 })

		local statusLbl = label({ Text = "", TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 6 }, form)
		local function setStatus(text, color)
			statusLbl.Text = text
			statusLbl.TextColor3 = color or C.sub
		end
		label({ Text = "Shadow v" .. VERSION, TextSize = 10, TextColor3 = P(110, 95, 104), TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, 0, 0, 14) }, card)

		local function shake()
			task.spawn(function()
				for i = 1, 6 do
					if not inputRow.Parent then return end
					inputRow.Position = UDim2.fromOffset(i % 2 == 0 and 6 or -6, 0)
					task.wait(0.04)
				end
				if inputRow.Parent then inputRow.Position = UDim2.new() end
			end)
		end

		local attempts, locked, busy = 0, false, false

		local function onSuccess(silent, exp)
			local note = ""
			if exp then
				local days = math.floor((exp - os.time()) / 86400)
				note = days <= 0 and "Expires today" or ("Expires in " .. days .. " day" .. (days == 1 and "" or "s"))
			end
			if STATE.keyInfo then STATE.keyInfo(exp) end
			tween(irs, 0.2, { Color = C.green, Transparency = 0 })
			setStatus(note ~= "" and ("Key accepted  |  " .. note) or "Key accepted", C.green)
			if KEYCFG.Remember then fileWrite("key.txt", trim(keyBox.Text)) end
			Notify({
				Title = silent and "Welcome back" or "Key accepted",
				Text = (silent and "Signed in with your saved key." or "Shadow unlocked.") .. (note ~= "" and ("  " .. note .. ".") or ""),
				Type = "success", Icon = "shield-check", Duration = 3,
			})
			task.delay(0.45, function() if alive then unlockHub() end end)
		end

		local function startLock(secs)
			locked = true
			task.spawn(function()
				for sec = secs, 1, -1 do
					if not alive then return end
					setBtn(verifyBtn, "Locked " .. sec .. "s", "lock")
					setStatus("Too many wrong keys, please wait", C.amber)
					task.wait(1)
				end
				if not alive then return end
				locked, attempts = false, 0
				setBtn(verifyBtn, "Verify Key", "shield-check")
				setStatus("", C.sub)
			end)
		end

		local function verify(silent)
			if busy or locked then return end
			busy = true
			setBtn(verifyBtn, "Checking", "loader-circle")
			spin(verifyBtn.Icon)
			setStatus("Checking key...", C.sub)

			local ok, msg, net = validateKey(keyBox.Text)
			unspin(verifyBtn.Icon)
			if not alive then return end

			if ok then
				setBtn(verifyBtn, "Unlocked", "check")
				busy = false
				onSuccess(silent, msg)
				return
			end

			setBtn(verifyBtn, "Verify Key", "shield-check")
			if net then
				setStatus(msg .. ", try again", C.amber)
				Notify({ Title = msg, Text = "Check your connection. This didn't use an attempt.", Type = "warn", Duration = 4 })
				busy = false
				return
			end
			if silent then
				setStatus("Saved key is no longer valid", C.amber)
				busy = false
				return
			end
			attempts = attempts + 1
			shake()
			tween(irs, 0.2, { Color = C.red, Transparency = 0 })
			local left = KEYCFG.MaxAttempts - attempts
			if left > 0 then
				setStatus(msg .. "  |  " .. left .. " attempt" .. (left == 1 and "" or "s") .. " left", C.red)
				Notify({ Title = msg, Text = left .. " attempt" .. (left == 1 and "" or "s") .. " remaining", Type = "error", Duration = 3 })
				busy = false
			else
				locked = true
				busy = false
				Notify({ Title = "Too many attempts", Text = "Locked for " .. KEYCFG.LockSeconds .. " seconds", Type = "warn", Duration = 4 })
				fileWrite("lock.txt", tostring(os.time() + KEYCFG.LockSeconds))
				startLock(KEYCFG.LockSeconds)
			end
		end

		bind(keyBox:GetPropertyChangedSignal("Text"), function()
			if busy or locked then return end
			tween(irs, 0.15, { Color = C.stroke, Transparency = 0.3 })
			setStatus("", C.sub)
		end)
		do
			local untilT = tonumber(fileRead("lock.txt") or "")
			if untilT and untilT > os.time() then startLock(math.ceil(untilT - os.time())) end
		end

		bind(verifyBtn.Button.MouseButton1Click, function() verify(false) end)
		bind(keyBox.FocusLost, function(enter) if enter then verify(false) end end)
		bind(getBtn.Button.MouseButton1Click, function()
			if copyText(KEYCFG.GetKeyLink) then
				Notify({ Title = "Key link copied", Text = "Paste it in your browser to get a key.", Type = "info", Icon = "link", Duration = 4 })
			else
				Notify({ Title = "Get your key here", Text = KEYCFG.GetKeyLink, Type = "info", Icon = "link", Duration = 8 })
			end
		end)

		tween(card, 0.45, { GroupTransparency = 0 })
		tween(kHalo, 0.7, { ImageTransparency = 0.5 })
		tween(kScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		STATE.dismissKey = function()
			STATE.dismissKey = nil
			tween(card, 0.35, { GroupTransparency = 1 })
			tween(kHalo, 0.35, { ImageTransparency = 1 })
			tween(kScale, 0.35, { Scale = 1.06 })
			task.delay(0.4, function()
				kg:Destroy()
				STATE.keyGui = nil
			end)
		end

		if KEYCFG.Remember then
			local saved = fileRead("key.txt")
			if saved and saved ~= "" then
				keyBox.Text = saved
				task.spawn(function()
					task.wait(0.8)
					if alive and STATE.keyGui then verify(true) end
				end)
			end
		end
	end)
	if not keyOk then unlockHub() end
end

local hidden = false
local setVisible

safeBuild("Float", function()
local FAB = 48
local fabHolder = frame({
	Name = "FloatToggle", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(64, 64),
	Position = UDim2.fromOffset(math.floor(vp.X / 2), TOP_INSET + 10 + 24), BackgroundTransparency = 1, ZIndex = 90,
	Visible = false,
}, gui)
local fabRing = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(FAB + 10, FAB + 10), BackgroundTransparency = 1 }, fabHolder)
round(fabRing, (FAB + 10) / 2)
local fabRingStroke = stroke(fabRing, C.white, 1.5, 0.5)
local fabRingGrad = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.redHi), ColorSequenceKeypoint.new(0.5, P(60, 14, 22)), ColorSequenceKeypoint.new(1, C.redHi),
	}),
}, fabRingStroke)

local fab = make("TextButton", {
	Name = "Toggle", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(FAB, FAB), BackgroundColor3 = C.white, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
}, fabHolder)
round(fab, FAB / 2)
gradient(fab, C.redHi, C.red2, 90)
stroke(fab, C.white, 1, 0.82)
local fabScale = make("UIScale", {}, fab)
local fabIcon = Icon(fab, "ghost", 24, C.white)
fabIcon.AnchorPoint = Vector2.new(0.5, 0.5)
fabIcon.Position = UDim2.fromScale(0.5, 0.5)
local fabDot = frame({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, -2), Size = UDim2.fromOffset(11, 11), BackgroundColor3 = C.green, ZIndex = 3 }, fab)
round(fabDot, 6)
stroke(fabDot, C.bg, 2, 0)

local pressStart = Vector2.new()
local function fabState()
	tween(fabDot, 0.2, { BackgroundColor3 = hidden and P(110, 95, 104) or C.green })
end

floatApply = function()
	fabHolder.Visible = hidden and (SETTINGS.FloatButton or UIS.TouchEnabled)
end

setVisible = function(v, hint)
if not unlocked then return end
	hidden = not v
	fabState()
	if v then
		root.Visible = true
		tween(win, 0.25, { GroupTransparency = 0 })
		tween(backdrop, 0.35, { GroupTransparency = 0 })
		STATE.fadeGlow(0.45, true)
		tween(introScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		tween(win, 0.2, { GroupTransparency = 1 })
		tween(backdrop, 0.2, { GroupTransparency = 1 })
		STATE.fadeGlow(0.25, false)
		tween(introScale, 0.2, { Scale = 0.9 })
		task.delay(0.22, function() if alive and hidden then root.Visible = false end end)
		if hint and not SETTINGS.FloatButton and not UIS.TouchEnabled then
			Notify({ Title = "Hidden", Text = "Press " .. toggleKey.Name .. " to show the UI again.", Type = "info", Duration = 3 })
		end
	end
	floatApply()
end

local BAR_H, SLOT, PADX = 60, 66, 10
local barItems = {
	{ name = "Home",       icon = "house",       tab = "Home" },
	{ name = "Editor",     icon = "code",        tab = "Editor" },
	{ name = "ScriptBlox", icon = "search",      tab = "ScriptBlox" },
	{ name = "Console",    icon = "terminal",    tab = "Console", optional = true },
	{ name = "Updates",    icon = "scroll-text", tab = "Updates" },
	{ name = "Settings",   icon = "settings",    tab = "Settings" },
}

local WS = {
	open = false, sel = nil, chosen = nil,
	vis = 0, visV = 0,
	active = {}, barW = 0, slotW = 0, left = 0, hlX = 0, hlV = 0, hlA = 0,
}

local function placeFab()
	local vs = gui.AbsoluteSize
	if vs.X > 0 then fabHolder.Position = UDim2.fromOffset(math.floor(vs.X / 2), TOP_INSET + 10 + FAB / 2) end
end
placeFab()
pcall(function()
	bind(GuiService:GetPropertyChangedSignal("TopbarInset"), function()
		local old = TOP_INSET
		TOP_INSET = readTopInset()
		if TOP_INSET == old then return end
		root.Size = UDim2.new(1, -MARGIN * 2, 1, -MARGIN * 2 - TOP_INSET)
		root.Position = UDim2.new(0.5, 0, 0.5, TOP_INSET / 2)
		NPOS.TopRight.pos = UDim2.new(1, -14, 0, 14 + TOP_INSET)
		NPOS.TopLeft.pos = UDim2.new(0, 14, 0, 14 + TOP_INSET)
		if not npos.bottom then notifHolder.Position = npos.pos end
		placeFab()
	end)
end)

local function barPos(e)
	return UDim2.fromOffset(fabHolder.Position.X.Offset, fabHolder.Position.Y.Offset + FAB / 2 + 8 - (1 - math.clamp(e, 0, 1)) * 16)
end

local bar = make("CanvasGroup", {
	Name = "TabBar", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(FAB, 0),
	Position = barPos(0), BackgroundColor3 = P(14, 12, 16), BackgroundTransparency = 0.04,
	BorderSizePixel = 0, ZIndex = 95, Visible = false, GroupTransparency = 1, Interactable = false,
}, gui)
round(bar, 999)
local barStroke = stroke(bar, C.white, 1.6, 0.2)
local barGrad = make("UIGradient", {
	Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.redHi), ColorSequenceKeypoint.new(0.5, P(50, 12, 20)), ColorSequenceKeypoint.new(1, C.redHi) }),
}, barStroke)
local barContent = frame({
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(100, BAR_H), BackgroundTransparency = 1,
}, bar)

local hl = frame({
	AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, BAR_H - 16),
	BackgroundColor3 = C.white, BackgroundTransparency = 1, ZIndex = 1,
}, barContent)
round(hl, 14)
gradient(hl, C.redHi, C.red2, 90)
local hlStroke = stroke(hl, C.white, 1, 1)

for _, it in ipairs(barItems) do
	it.hm, it.hmT, it.lift, it.liftT = 1, 1, 0, 0
	local cell = frame({
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, BAR_H - 16),
		BackgroundColor3 = C.white, BackgroundTransparency = 1, Visible = false,
	}, barContent)
	round(cell, 14)
	gradient(cell, C.redHi, C.red2, 90)
	it.scale = make("UIScale", { Scale = 0 }, cell)
	it.ic = Icon(cell, it.icon, 20, C.sub)
	it.ic.AnchorPoint = Vector2.new(0.5, 0)
	it.ic.Position = UDim2.new(0.5, 0, 0, 6)
	it.lbl = label({
		Text = it.name, Font = Enum.Font.GothamMedium, TextSize = 10, TextColor3 = C.sub,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 0, 0, 12),
	}, cell)
	it.cell = cell
end

local function spring(pos, vel, target, k, c, dt)
	local steps = math.max(1, math.ceil(dt / (1 / 120)))
	local h = dt / steps
	for _ = 1, steps do
		vel = vel + (k * (target - pos) - c * vel) * h
		pos = pos + vel * h
	end
	return pos, vel
end

local function layoutBar()
	local vs = gui.AbsoluteSize
	placeFab()
	bar.Position = barPos(0)
	WS.active = {}
	for _, it in ipairs(barItems) do
		local on = (not it.optional) or SETTINGS.Console
		it.cell.Visible = on
		if on then WS.active[#WS.active + 1] = it end
	end
	local n = #WS.active
	WS.barW = math.max(math.min(n * SLOT + PADX * 2, vs.X - 16), FAB)
	WS.left = (vs.X - WS.barW) / 2
	WS.slotW = (WS.barW - PADX * 2) / n
	barContent.Size = UDim2.fromOffset(WS.barW, BAR_H)
	for k, it in ipairs(WS.active) do
		it.cx = PADX + (k - 0.5) * WS.slotW
		it.cell.Position = UDim2.fromOffset(it.cx, BAR_H / 2)
		it.cell.Size = UDim2.fromOffset(math.clamp(WS.slotW - 8, 36, 64), BAR_H - 16)
	end
	hl.Size = UDim2.fromOffset(math.clamp(WS.slotW - 8, 36, 64), BAR_H - 16)
end

local function setBarSel(it)
	if WS.sel == it then return end
	if it and not WS.sel then WS.hlX, WS.hlV = it.cx, 0 end
	WS.sel = it
	for _, w in ipairs(barItems) do
		local on = (w == it)
		w.hmT = on and 1.08 or (it and 0.95 or 1)
		w.liftT = on and -2 or 0
		tween(w.lbl, 0.15, { TextColor3 = on and C.white or C.sub })
		tintIcon(w.ic, on and C.white or C.sub)
	end
end

local function openWheel()
	layoutBar()
	for _, it in ipairs(barItems) do
		if it.toggle then
			setIcon(it.ic, hidden and "eye" or "eye-off")
			it.lbl.Text = hidden and "Show UI" or "Hide UI"
		end
	end
	bar.GroupTransparency = 1
	bar.Size = UDim2.fromOffset(FAB, 0)
	bar.Visible = true
	WS.sel = false
	setBarSel(nil)
	WS.chosen = nil
	if WS.vis < 0.02 then WS.vis, WS.visV = 0, 0 end
	WS.open = true
	tween(fabScale, 0.2, { Scale = 0.9 })
end

local function closeWheel(chosen)
	WS.chosen = chosen
	if chosen then chosen.hmT, chosen.liftT = 1.1, -2 end
	WS.open = false
	tween(fabScale, 0.2, { Scale = 1 })
end

local function pickBar(x, delta)
	if math.abs(delta.X) < 16 and math.abs(delta.Y) < 16 then return nil end
	if delta.Y > 160 then return nil end
	local rel = x - WS.left - PADX
	if rel < 0 or rel > WS.barW - PADX * 2 then return nil end
	return WS.active[math.min(math.floor(rel / WS.slotW) + 1, #WS.active)]
end

local function hideWheel()
	WS.open, WS.vis, WS.visV, WS.chosen = false, 0, 0, nil
	bar.Visible = false
	tween(fabScale, 0.1, { Scale = 1 })
end

local function wheelAction(it)
	if not it.toggle and not unlocked then
		Notify({ Title = "Locked", Text = "Enter your key first.", Type = "warn", Icon = "lock", Duration = 2.5 })
		return
	end
	local function go()
		if not alive then return end
		hideWheel()
		if it.toggle then
			setVisible(hidden)
		else
			if hidden then setVisible(true) end
			showPage(it.tab)
		end
	end
	if hidden then task.delay(0.32, go) else go() end
end

bind(RS.RenderStepped, function(dt)
	local now = os.clock()
	fabRingGrad.Rotation = (now * 90) % 360
	local settled = (not WS.open) and WS.vis < 0.004 and math.abs(WS.visV) < 0.02
	if settled then
		if bar.Visible then
			bar.Visible = false
			WS.chosen = nil
		end
		return
	end
	barGrad.Rotation = (now * 70) % 360
	WS.vis, WS.visV = spring(WS.vis, WS.visV, WS.open and 1 or 0, 170, 17, dt)
	local e = math.max(WS.vis, 0)
	bar.Size = UDim2.fromOffset(FAB + (WS.barW - FAB) * e, BAR_H * math.clamp(e, 0, 1.04))
	bar.Position = barPos(e)
	bar.GroupTransparency = 1 - math.clamp(WS.vis * 3, 0, 1)
	local k = math.min(1, dt * 18)
	for _, it in ipairs(WS.active) do
		local dist = math.abs(it.cx - WS.barW / 2) / (WS.barW / 2)
		it.hm = it.hm + (it.hmT - it.hm) * k
		it.lift = it.lift + (it.liftT - it.lift) * k
		it.scale.Scale = math.clamp((e - dist * 0.55) / 0.45, 0, 1.08) * it.hm
		it.cell.Position = UDim2.fromOffset(it.cx, BAR_H / 2 + it.lift)
	end
	if WS.sel then WS.hlX, WS.hlV = spring(WS.hlX, WS.hlV, WS.sel.cx, 380, 26, dt) end
	WS.hlA = WS.hlA + (((WS.sel or WS.chosen) and 1 or 0) - WS.hlA) * k
	hl.Position = UDim2.fromOffset(WS.hlX, BAR_H / 2)
	hl.BackgroundTransparency = 1 - 0.95 * WS.hlA
	hlStroke.Transparency = 1 - 0.55 * WS.hlA
end)

local HOLD_TIME = 0.32
local pressing, holdToken = false, 0

local function endPress()
	if not pressing then return end
	pressing = false
	holdToken = holdToken + 1
	tween(fabRingStroke, 0.2, { Thickness = 1.5, Transparency = 0.5 })
	if WS.open then
		local it = WS.sel
		closeWheel(it)
		if it then wheelAction(it) end
	else
		setVisible(hidden)
	end
	tween(fabScale, 0.15, { Scale = 1 })
end

bind(fab.MouseEnter, function() if not pressing then tween(fabScale, 0.15, { Scale = 1.08 }) end end)
bind(fab.MouseLeave, function() if not pressing then tween(fabScale, 0.15, { Scale = 1 }) end end)
bind(fab.InputBegan, function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if pressing then return end
	pressing = true
	pressStart = Vector2.new(input.Position.X, input.Position.Y)
	holdToken = holdToken + 1
	local token = holdToken
	tween(fabScale, 0.15, { Scale = 0.94 })
	tween(fabRingStroke, HOLD_TIME, { Thickness = 3.5, Transparency = 0 })
	task.delay(HOLD_TIME, function()
		if alive and pressing and token == holdToken and not WS.open then
			openWheel()
		end
	end)
	local c
	c = input.Changed:Connect(function()
		if input.UserInputState == Enum.UserInputState.End then
			c:Disconnect()
			endPress()
		end
	end)
end)
bind(UIS.InputChanged, function(input)
	if not pressing or not WS.open then return end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
	local delta = Vector2.new(input.Position.X, input.Position.Y) - pressStart
	setBarSel(pickBar(input.Position.X, delta))
end)

end)

bind(closeBtn.MouseButton1Click, function() setVisible(false, true) end)
bind(UIS.InputBegan, function(input, processed)
	if rebinding then
		if input.UserInputType == Enum.UserInputType.Keyboard then rebinding(input.KeyCode) end
		return
	end
	if processed then return end
	if input.KeyCode == toggleKey and unlocked then setVisible(hidden) end
end)

local dragging, dragStart, startPos = false, nil, nil
local function hookDrag(obj)
	bind(obj.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = root.Position
			local c
			c = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					c:Disconnect()
				end
			end)
		end
	end)
end

bind(UIS.InputChanged, function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

local t = 0
local lastGlow = 0
bind(RS.RenderStepped, function(dt)
	t = t + dt
	strokeGrad.Rotation = (t * 70) % 360
	haloGrad.Rotation = (45 + t * 22) % 360
	if STATE.plateGrad then STATE.plateGrad.Rotation = (t * 40) % 360 end
	haloInnerGrad.Rotation = (225 - t * 30) % 360
	halo.ImageTransparency = 0.56 + 0.05 * math.sin(t * 1.4)
	if screenBg.Visible and t - lastGlow > 0.12 then
		lastGlow = t
		recolorGlow(t * 0.03)
	end
	titleStroke.Transparency = 0.35 + 0.25 * math.sin(t * 3)
	titleGrad.Offset = Vector2.new(0, 0.15 * math.sin(t * 2))
	for img in pairs(spinners) do
		if img.Parent then
			img.Rotation = (img.Rotation + dt * 360) % 360
		else
			spinners[img] = nil
		end
	end
end)

STATE.reveal = function()
	STATE.revealed = true
	root.Visible = true
	tween(win, 0.35, { GroupTransparency = 0 })
	tween(backdrop, 0.8, { GroupTransparency = 0 })
	tween(introScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
end
STATE.fadeGlow(1.1, true)
if not KEYCFG.Enabled or unlocked then
	STATE.reveal()
	if not unlocked then task.delay(0.3, unlockHub) end
end

return G2L, Notify