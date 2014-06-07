--
-- VNC client / server management
-- Requires the 'vnc' avfeed- interface frameserver
--
-- Client parts are a simplified version of the 'target' mode.
-- Server parts is a mixed hybrid using 'recording' as a basis.
--
local noalpha_fshader = [[
uniform sampler2D map_diffuse;
uniform float obj_opacity;

varying vec2 texco;

void main(void)
{
	gl_FragColor = vec4(texture2D(map_diffuse, texco).rgb, obj_opacity);
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

local function vncclient_setupwin(wnd, source)
	wnd.connected = true;
	wnd.input = function(self, iotbl)
		print("input:", iotbl.kind);
		target_input(source, iotbl);
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
		end
	};

	mouse_addlistener(canvash, {"click", "rclick", "motion", "press", "release"});
	table.insert(wnd.handlers, canvash);

	wnd.minput = function(self, iotbl, focused)
		if (focused) then
			wnd.input(wnd, iotbl);
		end
	end

	wnd.ainput = wnd.input;
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
	else
		print(status.kind);
	end
end

local function vncclient_connect(wnd, hoststr)
	local hp = string.split(hoststr, ":")
	local host;
	local port = 5900;

	if (hp[2] ~= nil) then
		port = tonumber(hp[2]);
		host = hp[1]
	else
		host = hoststr;
	end

	local vnc = launch_avfeed(string.format(
		"host=%s:port=%d:password=1234", host, port), function(source, status)
			vncclient_event(wnd, source, status);
		end);

	wnd.connection = vnc;
	image_sharestorage(vnc, wnd.canvas.vid);
	image_shader(wnd.canvas.vid, vnc_shader);
end

local function connectwin(pwin)
	local buttontbl = {
	{
		caption = desktoplbl("Connect"),
		trigger = function(own)
			vncclient_connect(pwin, own.inputfield.msg);
		end
	},
	{
		caption = desktoplbl("Cancel"),
		trigger = function(own)
		end
	}
	};

	local dlg = awbwman_dialog(desktoplbl("Connect To:"), buttontbl,
	{
		input = 
		{ w = 100, h = 20, limit = 48, accept = 1, cancel = 2 }
	}, false);

	pwin:add_cascade(dlg);
end

function spawn_vncclient(wnd)
	if (vnc_shader == nil) then
		vnc_shader = build_shader(nil, noalpha_fshader, "vncshader");
	end

	local wnd = awbwman_spawn(
		menulbl(MESSAGE["TOOL_VNCCLIENT"]), {refid = "vncclient"});
	
	local cfg = awbwman_cfg();
	local bar = wnd:add_bar("tt", cfg.ttactiveres, cfg.ttinactvres,
		wnd.dir.t.rsize, wnd.dir.t.bsize);

	bar:add_icon("connectpop", "l", cfg.bordericns["settings"], function(self)
		local lbls = {
			MESSAGE["NET_CONNECT"];
		};

	local cbtbl = {
		function(self) 
			connectwin(wnd); 
		end
	};

-- 1. log previously successfull connections and use as history  
		local vid, lines = desktoplbl(table.concat(lbls, "\\n\\r"));
		awbwman_popup(vid, lines, cbtbl, {ref = self.vid});
	end);

	wnd:add_handler("on_destroy", function()
		if (valid_vid(wnd.connection)) then
			delete_image(wnd.connection);
		end
	end);

	table.insert(wnd.handlers, bar);
	wnd.name = MESSAGE["TOOL_VNCCLIENT"];
end
