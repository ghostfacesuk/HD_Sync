-- "VBOX HD Sync.lua" -- VLC Extension script

-- adjustable defaults --
time_format=3 -- 1, 2, 3, 4
jumps = { -- drop-down list
	{"1/FPS", "vlcfps"},
[[	{"2 sec", 2},
	{"20 sec", 20},
--	{"30 sec", 30},
	{"1 min", "1:00"},
	{"5 min", "5:00"},
	{"10 min", "10:00"},
	{"1/2 sec", 0.5},
	{"1/x", "reciprocal"},
	{"1/23.976", 1/23.976},
	{"1/24", 1/24},
	{"1/25", 1/25},
	{"1/29.97", 1/29.97},
	{"1/30", 1/30},
	{"1/60", 1/60},]]
}

-------------------------

function descriptor()
	return {
		title = "VBOX HD Sync",
		version = "1.6",
		author = "SG",
--		shortdesc = "Jump to time (Previous frame)",
		description = [[
Jump to specific Video Frames
]],
		capabilities = {"menu"},
		icon = JTT_icon_string,
	}
end

function activate()
	Create_dialog()
	click_Get_time()
	click_Use_jump()
end

function deactivate()
end

function meta_changed()
end

function menu()
	return {"Show dialog","Help"}
end

help = [[
<style type="text/css">
body {background-color:white;}
#header{background-color:lightgreen;}
.tip{background-color:#FFFF7F;}
</style>

<body>
<div id=header>
<b>VBOX HD Sync</b> - Frame-accurate video sync tool<br />
</div>
<hr />

<b>How to use:</b><br />
1. Select "1/FPS" from dropdown and click "Use selected" to set frame rate<br />
2. Play video, pause at desired location<br />
3. Click "Get current time" to establish baseline<br />
4. Use "Frame Next >" / "< Frame Back" buttons to step through frames<br />
5. Each frame step will show the exact frame time<br />
<br />
<b>Note:</b> VLC's 'e' key won't update the time display. Use the Frame buttons instead.<br />
<br />
<b>Time format:</b> "HH:MM:SS,SSS"<br />
<hr />

</body>
]]
function trigger_menu(id)
	if id==1 then
		d:show()
	elseif id==2 then
		if not html_help then
			html_help = d:add_html(help,1,4,3,1)
			button_helpx = d:add_button("Hide help", function() d:del_widget(html_help) html_help=nil d:del_widget(button_helpx) end, 2,5,1,1)
		end
		d:show()
	end
end

function close()
	-- vlc.deactivate()
	d:hide()
end

----------------------

function Create_dialog()
	local ampersand="&" -- for button hotkeys (not OS X)
	local dir=""
	if not vlc.misc then
		dir = vlc.config.userdatadir()
	else
		dir = vlc.misc.userdatadir()
	end
	vlc.msg.info(dir)
	if string.match(dir,"^/Users/") then -- OS X
		ampersand=""
	end

	d = vlc.dialog(descriptor().title)

	-- Row 1: Time display and controls
	d:add_button(ampersand.."Get current time", click_Get_time, 1,1,1,1)
	textinput_time = d:add_text_input(Time2string(0), 2,1,1,1)
	d:add_button(""..ampersand.."Jump to time", click_Set_time, 3,1,1,1)

	-- Row 2: Frame stepping buttons (side by side, no dropdown between)
	d:add_button("< "..ampersand.."Frame", function() click_frame_step(-1) end, 1,2,1,1)
	d:add_button(ampersand.."Frame >", function() click_frame_step(1) end, 2,2,1,1)

	-- Row 3: FPS dropdown
	dropdown_jump = d:add_dropdown(1,3,2,1)
	for i,v in ipairs(jumps) do
		dropdown_jump:add_value(v[1],i)
	end
end

function click_Jump(direction)
	local input=vlc.object.input()
	if input then vlc.var.set(input, "time-offset", direction * String2time(textinput_jump:get_text())) end
end

function click_Use_jump()
	selected_jump = jumps[dropdown_jump:get_value()][2]
	if selected_jump=="reciprocal" then
		local number = string.gsub(textinput_jump:get_text(),",",".") -- various decimal separators
		number = tonumber(number)
		if number==nil or number==0 then
			return
		else
			textinput_jump:set_text(1/number)
		end
	elseif selected_jump=="vlcfps" then
		local fps = get_current_fps()
		if fps and fps > 0 then
			textinput_jump:set_text(1/fps)
			return
		end
		textinput_jump:set_text(0)
	else
		textinput_jump:set_text(selected_jump)
	end
end

local last_raw_time_us = nil
local last_pos = nil
local frame_base_time_us = nil
local frame_base_pictures = nil
local cached_fps = nil
local cached_fps_key = nil
local last_item_key = nil

function parse_fps_value(value)
	if value == nil then return nil end
	local s = tostring(value)
	s = string.gsub(s, ",", ".")
	local n = tonumber(s)
	if n and n > 0 then return n end
	local a, b = string.match(s, "(%d+)%s*/%s*(%d+)")
	if a and b then
		local num = tonumber(a)
		local den = tonumber(b)
		if num and den and den ~= 0 then return num / den end
	end
	return nil
end

function get_item_key()
	local item = vlc.input.item()
	if not item then return nil end
	local key = item:uri()
	if not key or key == "" then key = item:name() end
	return key
end

function get_item_fps()
	local item = vlc.input.item()
	if not item then return nil end
	local info = item:info()
	if not info then return nil end
	for _, group in pairs(info) do
		for k, v in pairs(group) do
			local kl = string.lower(tostring(k))
			if string.find(kl, "frame rate", 1, true) or string.find(kl, "fps", 1, true) then
				local fps = parse_fps_value(v)
				if fps and fps > 0 then return fps end
			end
		end
	end
	return nil
end

function get_current_fps()
	local key = get_item_key()
	if cached_fps and cached_fps_key == key then return cached_fps end
	cached_fps = nil
	cached_fps_key = key

	local input = vlc.object.input()
	if input then
		local fps = parse_fps_value(vlc.var.get(input, "fps"))
		if fps and fps > 0 then
			cached_fps = fps
			return cached_fps
		end
	end

	local fps = get_item_fps()
	if fps and fps > 0 then
		cached_fps = fps
		return cached_fps
	end

	if dropdown_jump and textinput_jump then
		local idx = dropdown_jump:get_value()
		local entry = idx and jumps[idx]
		if entry and entry[2] == "vlcfps" then
			local sec = tonumber(string.gsub(textinput_jump:get_text(), ",", "."))
			if sec and sec > 0 then
				cached_fps = 1 / sec
				return cached_fps
			end
		end
	end

	return nil
end

function get_displayed_pictures()
	local item = vlc.input.item()
	if not item then return nil end
	local stats = item:stats()
	if stats and stats.displayed_pictures then return stats.displayed_pictures end
	return nil
end

local last_displayed_pictures = nil
local last_reliable_time_us = nil
local last_reliable_pictures = nil

-- Manual frame tracking for accurate frame stepping
local manual_frame_base_time_us = nil
local manual_frame_offset = 0
local manual_tracking_enabled = false

function get_current_time_us()
	local input=vlc.object.input()
	if not input then return nil end

	local item_key = get_item_key()
	if item_key ~= last_item_key then
		last_item_key = item_key
		last_raw_time_us = nil
		last_pos = nil
		frame_base_time_us = nil
		frame_base_pictures = nil
		last_displayed_pictures = nil
		last_reliable_time_us = nil
		last_reliable_pictures = nil
		manual_frame_base_time_us = nil
		manual_frame_offset = 0
		manual_tracking_enabled = false
	end

	-- Get FPS and frame duration first
	local fps = get_current_fps()
	local frame_us = nil
	if fps and fps > 0 then
		frame_us = 1000000.0 / fps
	end

	-- Get VLC's current time
	local time_us = vlc.var.get(input, "time")

	-- If manual frame tracking is active, use it
	if manual_tracking_enabled and manual_frame_base_time_us and frame_us then
		local calculated_time = manual_frame_base_time_us + math.floor(manual_frame_offset * frame_us + 0.5)
		return calculated_time
	end

	-- Otherwise return VLC's reported time
	return time_us
end

function click_Get_time()
	local time_us = get_current_time_us()
	if time_us then
		textinput_time:set_text(Time2string(time_us))

		-- Enable manual tracking and set baseline when getting current time
		manual_frame_base_time_us = time_us
		manual_frame_offset = 0
		manual_tracking_enabled = true

		-- Debug info
		local fps = get_current_fps()
		vlc.msg.info(string.format("Baseline set: %s | FPS: %s | Manual tracking: ENABLED",
			Time2string(time_us),
			fps and string.format("%.3f", fps) or "unknown"))
	end
end

function click_frame_step(direction)
	local input = vlc.object.input()
	if not input then
		vlc.msg.warn("No input object")
		return
	end

	local fps = get_current_fps()
	if not fps or fps <= 0 then
		vlc.msg.warn("FPS not detected. Select 1/FPS from dropdown first.")
		return
	end

	-- Pause the video if it's playing (frame step only works when paused)
	if vlc.playlist.status() == "playing" then
		vlc.playlist.pause()
		vlc.msg.info("Paused video for frame stepping")
	end

	-- Enable manual tracking if not already enabled
	if not manual_tracking_enabled then
		local time_us = vlc.var.get(input, "time")
		if time_us then
			manual_frame_base_time_us = time_us
			manual_frame_offset = 0
			manual_tracking_enabled = true
			vlc.msg.info("Manual tracking enabled at: " .. Time2string(time_us))
		end
	end

	-- Step the frame in VLC (only forward stepping is reliable in VLC API)
	if direction > 0 then
		vlc.var.set(input, "frame-next", nil)
		vlc.msg.info("Stepping forward")
	else
		-- Backward frame stepping: jump back slightly then step forward
		local frame_us = 1000000.0 / fps
		local current_time = vlc.var.get(input, "time")
		-- Jump back 2 frames, VLC will land nearby, then we track from there
		local target_time = current_time - (frame_us * 2)
		if target_time < 0 then target_time = 0 end
		vlc.var.set(input, "time", target_time)
		vlc.msg.info("Stepping backward (jump back method)")
	end

	-- Update our manual frame counter
	manual_frame_offset = manual_frame_offset + direction

	-- Update display
	local time_us = get_current_time_us()
	if time_us then
		textinput_time:set_text(Time2string(time_us))
		vlc.msg.info(string.format("Frame %+d | Time: %s", manual_frame_offset, Time2string(time_us)))
	end
end

function click_reset_tracking()
	manual_tracking_enabled = false
	manual_frame_offset = 0
	manual_frame_base_time_us = nil
	vlc.msg.info("Manual tracking reset")
end

function click_Set_time()
	local input=vlc.object.input()
	if input then
		vlc.var.set(input,"time",String2time(textinput_time:get_text()))
		-- Reset manual tracking when jumping to a new time
		manual_tracking_enabled = false
		manual_frame_offset = 0
		manual_frame_base_time_us = nil
	end
end

function click_Switch_time_format()
	local ts=textinput_time:get_text()
	local ct=String2time(ts)
	local cts=Time2string(ct)
	if cts==ts then
		time_format = time_format - 1
		if time_format==0 then time_format = 4 end
		cts=Time2string(ct)
	end
	textinput_time:set_text(cts)
end

function Time2string(timestamp)
	timestamp=timestamp/1000000 -- VLC 3 microseconds fix
	if not time_format then time_format=3 end
	if time_format==3 then -- H:m:s,ms
		return string.format("%02d:%02d:%06.3f", math.floor(timestamp/3600), math.floor(timestamp/60)%60, timestamp%60):gsub("%.",",")
	elseif time_format==2 then -- M:s,ms
		return string.format("%02d:%06.3f", math.floor(timestamp/60), timestamp%60):gsub("%.",",")
	elseif time_format==1 then -- S,ms
		return string.format("%5.3f", timestamp):gsub("%.",",")
	elseif time_format==4 then -- D/h:m:s,ms
		return string.format("%d/%02d:%02d:%06.3f", math.floor(timestamp/(24*60*60)), math.floor(timestamp/(60*60))%24, math.floor(timestamp/60)%60, timestamp%60):gsub("%.",",")
	end
end

function String2time(timestring)
	timestring=string.gsub(timestring,",",".") -- various decimal separators
	local tt=ReverseTable(SplitString(timestring,"[:/%*%-%+]")) -- delimiters :/*-+
	return ((tonumber(tt[1]) or 0) + (tonumber(tt[2]) or 0)*60 + (tonumber(tt[3]) or 0)*3600 + (tonumber(tt[4]) or 0)*24*3600)*1000000 -- VLC 3 microseconds fix
end

function SplitString(s, d) -- string, delimiter pattern
	local t={}
	local i=1
	local ss, j, k
	local b=false
	while true do
		j,k = string.find(s,d,i)
		if j then
			ss=string.sub(s,i,j-1)
			i=k+1
		else
			ss=string.sub(s,i)
			b=true
		end
		table.insert(t, ss)
		if b then break end
	end
	return t
end

function ReverseTable(t) -- table
	local rt={}
	local n=#t
	for i, v in ipairs(t) do
		rt[n-i+1]=v
	end
	return rt
end

JTT_icon_string = "\137\80\78\71\13\10\26\10\0\0\0\13\73\72\68\82\0\0\0\32\0\0\0\32\8\3\0\0\0\68\164\138\198\0\0\0\25\116\69\88\116\83\111\102\116\119\97\114\101\0\65\100\111\98\101\32\73\109\97\103\101\82\101\97\100\121\113\201\101\60\0\0\3\0\80\76\84\69\185\219\237\237\237\237\121\255\121\0\34\0\1\226\1\218\234\241\18\52\72\242\255\242\145\145\145\201\226\239\140\255\140\54\231\96\173\255\173\42\246\42\54\67\74\20\199\20\97\99\97\42\148\208\157\205\234\0\108\0\162\162\162\0\169\0\0\251\0\36\131\188\0\69\0\72\255\72\170\212\236\0\150\0\205\255\205\130\132\133\0\203\0\54\83\101\76\77\77\253\253\253\41\146\206\57\170\224\242\242\243\0\241\0\210\210\210\89\152\185\27\88\122\139\198\233\42\42\42\61\61\61\90\92\92\49\158\216\200\203\204\164\209\235\53\149\195\78\105\123\0\54\0\45\152\211\102\186\230\20\235\61\78\179\229\91\183\230\2\8\3\59\168\220\0\196\0\66\175\226\46\155\213\52\53\52\11\29\39\109\109\109\39\157\39\124\193\232\0\19\0\25\33\36\0\119\0\134\196\232\0\238\0\72\238\98\51\161\218\192\192\192\84\181\229\82\83\84\149\202\234\61\173\227\70\74\75\142\142\142\36\138\201\67\176\228\225\255\225\40\121\165\35\134\194\155\164\167\20\241\20\0\221\0\0\187\0\54\166\222\47\156\214\28\252\32\51\209\52\20\20\19\0\85\0\53\164\220\23\69\91\37\140\202\59\172\226\0\179\0\18\69\101\26\102\150\121\121\121\179\215\237\115\115\115\69\69\69\38\130\182\73\177\228\50\79\96\45\147\201\59\93\115\91\125\147\0\136\0\51\255\51\108\255\108\52\163\219\216\255\216\105\255\105\249\255\249\135\255\135\0\142\0\0\210\0\255\255\255\156\255\156\39\143\204\182\182\182\54\165\221\210\255\210\198\255\198\222\255\222\150\255\150\120\191\232\201\255\201\0\213\0\0\135\0\113\189\231\159\255\159\117\255\117\41\129\175\35\137\198\102\255\102\252\255\252\129\255\129\165\255\165\213\255\213\0\216\0\192\255\192\138\140\139\87\255\87\26\74\98\55\168\223\129\195\232\211\241\211\123\188\123\55\242\55\21\248\31\106\152\107\170\220\221\147\170\183\137\139\141\19\73\107\53\231\53\14\236\15\170\201\191\74\229\80\17\136\17\55\243\56\113\240\124\27\177\27\40\85\39\31\127\186\7\158\8\133\136\137\53\163\220\202\214\222\38\195\49\126\255\126\40\190\40\40\88\117\135\249\135\20\119\107\32\109\154\38\56\65\128\217\130\103\236\129\109\241\128\192\202\209\125\240\144\167\235\192\207\229\240\24\75\104\166\175\181\89\231\126\116\242\131\17\255\17\173\173\173\27\250\31\106\115\119\24\245\24\87\208\169\117\222\128\115\196\217\50\170\80\230\230\230\99\132\152\127\129\129\115\139\152\102\111\118\39\199\153\4\242\5\68\146\68\95\184\230\189\203\206\32\154\175\45\101\128\37\221\38\50\122\157\35\137\200\32\162\168\97\182\227\79\195\79\107\187\231\150\152\152\32\245\47\8\230\10\36\125\177\65\161\80\71\190\71\114\119\121\115\122\124\42\147\207\194\223\238\85\218\85\195\198\198\2\209\7\181\226\181\139\139\139\180\255\180\100\213\171\108\131\115\235\235\235\5\209\5\91\198\97\29\112\163\248\248\248\23\72\98\151\151\151\96\184\230\104\177\217\43\207\140\31\99\136\0\153\0\0\51\0\0\255\0\0\0\0\255\255\255\234\138\63\81\0\0\1\0\116\82\78\83\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\0\83\247\7\37\0\0\3\38\73\68\65\84\120\218\116\148\119\76\19\81\28\199\31\92\33\197\1\133\182\112\72\44\98\83\69\91\16\17\241\4\90\164\156\7\84\41\16\71\171\192\129\162\8\184\218\18\98\33\194\63\6\156\9\33\40\42\238\189\247\222\123\198\189\113\239\29\103\226\234\221\59\223\221\21\193\68\223\63\47\247\190\159\207\239\253\46\247\107\1\247\159\53\221\189\131\127\166\142\106\146\140\115\252\13\120\182\6\66\32\90\78\71\11\224\136\35\201\106\71\115\188\85\9\133\21\215\2\56\249\231\144\102\64\99\132\4\67\64\136\5\186\129\73\86\209\80\186\175\113\66\154\178\75\24\94\241\20\128\64\12\10\138\81\35\228\172\81\62\27\109\18\2\50\20\169\1\8\66\45\49\18\59\69\67\167\0\168\162\249\210\117\42\28\105\54\14\104\72\138\129\132\4\29\205\150\27\249\164\86\169\154\134\54\11\202\33\161\145\1\174\6\181\131\171\234\248\171\162\85\124\133\114\177\147\213\114\116\126\59\17\112\26\4\64\220\34\20\87\214\186\95\100\99\113\46\179\141\132\206\29\10\192\5\163\90\242\96\241\156\151\21\50\189\190\251\251\162\10\197\188\64\188\224\154\47\224\223\138\44\19\243\55\11\7\104\139\59\85\102\132\73\43\20\30\82\217\83\75\249\78\3\2\10\112\212\91\100\253\67\93\119\189\86\113\194\3\197\105\3\100\190\163\70\175\111\186\121\55\136\0\220\187\114\201\158\139\102\183\25\217\243\194\184\9\40\11\55\100\142\152\220\217\191\87\130\55\168\215\173\99\180\137\149\149\162\105\30\20\148\201\71\37\68\9\74\35\34\74\7\1\153\44\237\155\71\225\229\208\137\130\233\189\203\255\165\63\31\25\126\69\164\230\13\107\80\247\5\159\50\194\150\44\222\110\24\220\196\155\47\195\243\123\37\12\143\72\77\205\11\247\86\171\71\198\143\53\93\7\200\92\250\117\48\241\68\52\199\27\102\164\150\86\53\168\211\163\12\241\177\125\98\166\38\245\7\51\121\211\255\240\97\193\44\173\202\159\211\32\152\247\146\187\78\153\219\109\96\64\15\208\98\230\161\40\253\142\33\75\52\67\123\6\244\232\48\6\188\2\195\255\152\35\179\98\77\49\63\8\209\236\112\201\23\0\159\67\94\94\160\116\19\186\242\74\111\246\237\79\83\76\91\150\109\187\251\252\35\54\101\204\222\147\236\134\99\217\108\142\46\17\68\169\211\179\98\123\227\104\56\206\125\64\147\197\110\113\49\208\114\80\133\65\155\5\131\202\118\82\112\203\244\253\193\25\43\180\26\85\11\142\166\184\32\107\69\95\118\101\199\126\67\25\218\70\225\120\163\12\236\78\234\223\109\224\35\6\210\143\49\219\62\4\144\16\210\57\105\141\56\116\189\246\163\107\86\153\1\129\154\93\68\225\52\180\100\175\249\194\3\140\11\90\230\47\243\195\141\87\41\134\90\193\129\228\197\62\62\7\92\12\5\149\203\159\229\32\192\101\116\65\74\66\219\108\216\73\90\101\71\99\111\62\117\99\200\71\10\67\77\98\54\23\26\173\207\12\172\145\99\54\104\180\162\39\198\206\1\93\97\81\23\105\155\161\108\251\251\167\251\173\101\217\219\103\237\108\89\141\124\22\123\156\43\99\89\190\194\183\10\105\197\197\52\153\62\55\215\252\226\200\102\113\178\38\181\250\153\2\237\70\125\114\174\246\249\144\253\255\249\27\248\45\192\0\38\39\86\205\244\203\80\251\0\0\0\0\73\69\78\68\174\66\96\130"
