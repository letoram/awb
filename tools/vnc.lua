--
-- VNC client management
-- Requires the 'remoting' avfeed- interface frameserver
-- or an external_alloc that has exposed that classid.
--
-- Possible ideas;
--  1. keymap bind
--  2. macro recording / playback
--  3. button to zoom / reset zoom, region selector
--     on canvas, meta + mouse to pan
--
local bw_fifty_shader = [[
uniform sampler2D map_diffuse;
uniform float obj_opacity;

varying vec2 texco;

void main(void)
{
	vec3 col = texture2D(map_diffuse, texco).rgb;
	float intens = 0.5 * (( col.r + col.g + col.b ) / 3.0);

	gl_FragColor = vec4(intens, intens, intens, obj_opacity);
}
]];

local function mouse_motion(dst, x, y)
	local iotbl = {
		devid = 0,
		subid = 0,
		kind = "analog",
		source = "mouse",
		pts = 0,
		samples = {x, 0},
	};

	target_input(dst, iotbl);
	iotbl.samples[1] = y;
	iotbl.subid = 1;
	target_input(dst, iotbl);
end

local function mouse_button(dst, ind, active)
	local iotbl = {
		devid = 0,
		subid = ind,
		kind = "digital",
		source = "mouse",
		active = active;
	};

	target_input(dst, iotbl);
end

local function key_input(dst, btns, state)
	local iotbl =
	{
		devid = 0,
		subid = 0,
		kind = "translated",
		source = "keyboard",
		active = state
	};

	for k,v in ipairs(btns) do
		if (symtable[v]) then
			iotbl.keysym = symtable[v];
			target_input(dst, iotbl);
		else
			warning(string.format(
				"no matching keysym found for (%s)\n", tostring(k)));
		end
	end
end

local function datashare(wnd)
	local res = awbwman_setup_cursortag(sysicons.floppy);
	res.kind = "media";
	res.name = wnd.name;
	res.factory = "";

	res.shortcut_trig = function()
		local lines = {
			"res.kind = \"tool\";",
			"res.type = \"vnc\";"
		};
		table.insert(lines, string.format("res.host = %q;", wnd.host));
		table.insert(lines, string.format("res.port = %d;", wnd.port));
		table.insert(lines, string.format("res.pass = %q;", wnd.pass));
		return table.concat(lines, "\n");
	end

	res.caption = "VNC(%s)";
	res.icon = "vnc";
	res.source = wnd;
end

local function vnc_keypopup(wnd, icn)
	local keyopts = {
		"Reset State Modifiers",
		"Ctrl+Escape",
		"Ctrl+Alt+Backspace",
		"Ctrl+Alt+Del",
		"Alt+F4"
	};

	local keycbs = {
		function()
			reset_target(wnd.controlid);
		end,
		function()
			key_input(wnd.controlid, {"LCTRL", "ESCAPE"}, true);
			key_input(wnd.controlid, {"LCTRL", "ESCAPE"}, false);
		end,
		function()
			key_input(wnd.controlid, {"LCTRL", "RALT", "BACKSPACE"}, true);
			key_input(wnd.controlid, {"LCTRL", "RALT", "BACKSPACE"}, false);
		end,
		function()
			key_input(wnd.controlid, {"LCTRL", "RALT", "DELETE"}, true);
			key_input(wnd.controlid, {"LCTRL", "RALT", "DELETE"}, false);
		end,
		function()
			key_input(wnd.controlid, {"LALT", "F4"}, true);
			key_input(wnd.controlid, {"LALT", "F4"}, false);
		end
	};

	local vid, lines = desktoplbl(table.concat(keyopts, "\\n\\r"));
	awbwman_popup(vid, lines, keycbs, {ref = icn.vid});
end

local function vncclient_setupwin(wnd, source)
	wnd.connected = true;
	show_image(source);
	wnd:update_canvas(source);

	resize_image(source, wnd.canvasw, wnd.canvash);

	wnd.input = function(self, iotbl)
		target_input(source, iotbl);
	end

-- some vnc servers may need (if bandwidth permits) to have
-- full refreshes requested periodically.
	wnd.clock_pulse = function()
		if (wnd.periodic ~= nil) then
			wnd.periodic = wnd.periodic - 1;
			if (wnd.periodic == 0) then
				stepframe_target(source, 0);
				wnd.periodic = wnd.periodic_base;
			end
		end
	end

	local canvash = {
		name = "vnc_canvas",
		own = function(self, vid)
			return vid == wnd.canvas.vid;
		end,
		motion = function(ctx, vid, x, y)
			local props = image_surface_resolve_properties(wnd.canvas.vid);
			local sprops = image_storage_properties(wnd.canvas.vid);

			mouse_motion(source,
				(x - props.x) / props.width * sprops.width,
				(y - props.y) / props.height * sprops.height);
		end,
		click = function()
			wnd:focus();
		end,
		press = function()
			mouse_button(source, 0, true);
		end,
		release = function()
			mouse_button(source, 0, false);
		end,
		rclick = function()
			mouse_button(source, 1, true);
			mouse_button(source, 1, false);
		end,
		over = function()
			local tag = awbwman_cursortag();
			if (tag) then
				tag:hint(false);
			end
			if (wnd.mouse_hide) then
				mouse_hide();
			end
		end,
		out = function()
			local tag = awbwman_cursortag();
			if (tag) then
				tag:hint(false);
			end
			mouse_show();
		end
	};

	mouse_addlistener(canvash, {"click", "rclick",
		"motion", "press", "release", "over", "out"});
	table.insert(wnd.handlers, canvash);

-- only happens in fullscreen, rescale coordinates
	wnd.minput = function(self, iotbl, focused)
		if (iotbl.kind == "analog") then
			local sprops = image_storage_properties(wnd.canvas.vid);
			local props = image_surface_resolve_properties(
				awbwman_cfg().fullscreen.vid);

-- calculate fullscreen coordinates and clamp
			wnd.fs_mx = wnd.fs_mx + (iotbl.subid == 0 and iotbl.samples[2] or 0);
			wnd.fs_my = wnd.fs_my + (iotbl.subid == 1 and iotbl.samples[2] or 0);
			wnd.fs_mx = wnd.fs_mx < props.x and props.x or wnd.fs_mx;
			wnd.fs_mx = wnd.fs_mx > (props.x + props.width)
				and (props.x + props.width) or wnd.fs_mx;
			wnd.fs_my = wnd.fs_my < props.y and props.y or wnd.fs_my;
			wnd.fs_my = wnd.fs_my > (props.y + props.height)
				and (props.y + props.height) or wnd.fs_my;

			mouse_motion(source,
				(wnd.fs_mx - props.x) / props.width * sprops.width,
				(wnd.fs_my - props.y) / props.height * sprops.height);
		else
			mouse_button(source, iotbl.subid-1, iotbl.active);
		end
	end

	local cfg = awbwman_cfg();
	local bar = wnd.dir.tt;

	if (bar.left[1]) then
		bar.left[1]:destroy();
	end

	wnd.fs_mx = 0;
	wnd.fs_my = 0;

	wnd.hoverlut[
		bar:add_icon("hide_cursor", "l", cfg.bordericns["hide_cursor"],
		function(self)
			wnd.mouse_hide = not wnd.mouse_hide;
			image_sharestorage(cfg.bordericns[wnd.mouse_hide
				and "show_cursor" or "hide_cursor"], self.vid);

		end).vid
	] = MESSAGE["HOVER_CURSORHIDE"];

	wnd.hoverlut[
		bar:add_icon("special_key", "l", cfg.bordericns["special_key"],
		function(self)
			vnc_keypopup(wnd, self);
		end).vid
	] = MESSAGE["HOVER_SPECIALKEY"];

	wnd.hoverlut[
		bar:add_icon("performance", "l", cfg.bordericns["hide_cursor"],
		function(self)
			print("performance");
		end).vid
	] = MESSAGE["HOVER_PERFORMANCE"];

	wnd.hoverlut[
		bar:add_icon("clone", "r", cfg.bordericns["clone"],
		function(self)
			datashare(wnd);
		end).vid
	] = MESSAGE["HOVER_CLONE"];

	stepframe_target(source, 0);
end

local function vncclient_event(wnd, source, status)
	if (status.kind == "resized") then
		if (not wnd.connected) then
			vncclient_setupwin(wnd, source);
		end
	elseif (status.kind == "frameserver_terminated") then
		if (wnd.connected) then
			wnd.connected = nil;
			wnd.input = nil;
			wnd.ainput = nil;
		end

		image_shader(wnd.canvas.vid, vnc_shader);
	else
		print(status.kind);
	end
end

local function vncclient_connect(wnd, hoststr, pass)
	local hp = string.split(hoststr, ":")
	local host;
	local port = 5900;

	if (#hp > 2) then
		warning("no ipv6 parsing yet");
		return;
	end

	if (hp[2] ~= nil) then
		port = tonumber(hp[2]);
		host = hp[1]
	else
		host = hoststr;
	end

	local vnc = launch_avfeed(string.format(
		"host=%s:port=%d:password=%s", host, port, pass),
		function(source, status)
			vncclient_event(wnd, source, status);
		end);

	target_flags(vnc, TARGET_NOALPHA, 1);

	wnd.host = host;
	wnd.port = port;
	wnd.pass = pass;
	wnd.controlid = vnc;
end

local function dlgwin(pwin, msgl, label, cb)
	local buttontbl = {
	{
		caption = desktoplbl(msgl),
		trigger = function(own)
			cb(pwin, own.inputfield.msg);
		end
	},
	{
		caption = desktoplbl("Cancel"),
		trigger = function(own)
		end
	}
	};

	local dlg = awbwman_dialog(desktoplbl(label), buttontbl,
	{
		input =
		{ w = 100, h = 20, limit = 48, accept = 1, cancel = 2 }
	}, false);

	pwin:add_cascade(dlg);
end

function spawn_vncclient(tbl, fact)
	if (vnc_shader == nil) then
		vnc_shader = build_shader(nil, bw_fifty_shader, "vncshader");
	end

	local wnd = awbwman_spawn(
		menulbl(MESSAGE["TOOL_VNCCLIENT"]), {
			refid = "vncclient", fullscreen = true});

	wnd.hoverlut = {};
	wnd.mouse_hide = false;

	local cfg = awbwman_cfg();
	local bar = wnd:add_bar("tt", cfg.ttactiveres, cfg.ttinactvres,
		wnd.dir.t.rsize, wnd.dir.t.bsize);

	bar.hover = function(self, vid, x, y, state)
		if (state == false) then
			awbwman_drophover();
		elseif (wnd.hoverlut[vid]) then
			awbwman_hoverhint(wnd.hoverlut[vid]);
		end
	end

	bar.click = function()
		wnd:focus(true);
	end

	mouse_addlistener(bar, {"click", "hover"});

	wnd:add_handler("on_destroy", function()
		if (valid_vid(wnd.controlid)) then
			delete_image(wnd.controlid);
		end
	end);

	table.insert(wnd.handlers, bar);
	wnd.name = MESSAGE["TOOL_VNCCLIENT"];

	if (tbl == nil) then
	bar:add_icon("connectpop", "l", cfg.bordericns["connect"], function(self)
		local lbls = {
			MESSAGE["NET_CONNECT"];
		};

	local cbtbl = {
		function(self)
			dlgwin(wnd, "OK", "Specify host (host, host:port, :port)",
			function(wnd, host)
				dlgwin(wnd, "Connect", "Password:", 
				function(wnd, pass)
					vncclient_connect(wnd, host, pass);
				end);
			end);
		end
	};

		local vid, lines = desktoplbl(table.concat(lbls, "\\n\\r"));
		awbwman_popup(vid, lines, cbtbl, {ref = self.vid});
	end);
	else
		vncclient_connect(wnd, tbl.host .. ":" .. tbl.port, tbl.pass);
	end
end
