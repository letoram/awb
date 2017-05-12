local animtexco_vshader = [[
uniform mat4 modelview;
uniform mat4 projection;
uniform int timestamp;

uniform vec2 speedfact;

attribute vec4 vertex;
attribute vec2 texcoord;

varying vec2 texco;

void main(void)
{
        texco.s = texcoord.s + fract(float(timestamp) / speedfact.x);
        texco.t = texcoord.t + fract(float(timestamp) / speedfact.y);

        gl_Position = (projection * modelview) * vertex;
}
]];

function awbwnd_breakdisplay(wnd)
	switch_default_texmode( TEX_REPEAT, TEX_REPEAT );
	wnd:update_canvas(random_surface(128, 128));
  switch_default_texmode( TEX_CLAMP, TEX_CLAMP );
	wnd.broken = true;

	if (wnd.dir.tt) then
		wnd.dir.tt:destroy();
	end

	wnd.rebuild_chain = function() end
	wnd.shid = build_shader(animtexco_vshader, nil, "vid_" .. wnd.wndid);
	if (wnd.shid ~= nil) then
		shader_uniform(wnd.shid, "speedfact", "ff", PERSIST, 12.0, 12.0);
		image_shader(wnd.canvas.vid, wnd.shid);
	end

	wnd:resize(wnd.canvasw, wnd.canvash, true);
end

local function datashare(wnd)
	local res  = awbwman_setup_cursortag(sysicons.floppy);
	res.kind   = "media";
	res.source = wnd;
	res.audio  = wnd.recv;
	res.name   = wnd.name;
	return res;
end

local function cli_handler(pwin, source, status)
	if (pwin.alive == false) then
		return;
	end

	if (pwin.controlid == nil) then
		pwin:update_canvas(source);
	end

	if (status.kind == "resized") then
		print("resized to", status.width, status.height);
--		pwin:resize(status.width, status.height, true, true);

	elseif (status.kind == "preroll") then
		target_fonthint(source, deffont, deffont_sz, 0, 0);
		local cw = image_surface_resolve(pwin.canvas.vid);
		target_displayhint(source, cw.width, cw.height, 0, {
			ppcm = VPPCM, subpixel_layout = "rgb"
		});

	elseif (status.kind == "terminated") then
		pwin:break_display();

	elseif (status.kind == "streamstatus") then
		awbmedia_update_streamstats(pwin, status);
	end
end

function awbwnd_cli(pwin, source, options)
	local kind = pwin.kind;

	pwin.filters = {};
	pwin.hoverlut = {};

	pwin.rebuild_chain = awbwmedia_filterchain;
	pwin.break_display = awbwnd_breakdisplay;

	pwin:add_handler("on_destroy",
		function(self)
			if (pwin.filtertmp ~= nil) then
				for i, v in ipairs(pwin.filtertmp) do
					if (valid_vid(v)) then delete_image(v); end
				end
			end

			if (valid_vid(pwin.controlid)) then
				delete_image(pwin.controlid);
				pwin.controlid = nil;
			end
		end
	);

	pwin.canvas.resize =
	function(canvas, winw, winh, cnvw, cnvh)
		resize_image(pwin.canvas.vid, pwin.canvasw, pwin.canvash);
		if (valid_vid(pwin.controlid, TYPE_FRAMESERVER)) then
			target_displayhint(pwin.controlid, pwin.canvasw, pwin.canvash);
		end
	end;

	local canvash = {
		name  = kind .. "_canvash",
		own   = function(self, vid)
							return vid == pwin.canvas.vid;
						end,
		click = function()
							pwin:focus();
						end
	}

	pwin.input = function(self, iotbl)
		if (valid_vid(pwin.controlid, TYPE_FRAMESERVER)) then
			target_input(pwin.controlid, iotbl);
		end
	end

	mouse_addlistener(canvash, {"click"});
	table.insert(pwin.handlers, canvash);

	local bar = pwin:add_bar("tt", pwin.ttbar_bg, pwin.ttbar_bg,
		pwin.dir.t.rsize, pwin.dir.t.bsize);
	bar.name = "vmedia_ttbarh";

	local cfg = awbwman_cfg();

	bar.hoverlut[
	(bar:add_icon("clone", "r", cfg.bordericns["clone"],
		function() datashare(pwin); end)).vid] =
	MESSAGE["HOVER_CLONE"];

	return function(source, status)
		cli_handler(pwin, source, status);
	end
end
