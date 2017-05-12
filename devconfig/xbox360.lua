local tbl = {
	analog = {
		"Lstick X",
		"Lstick Y",
		"L/R Trigger",
		"Rstick Y",
		"Unknown",
		"Unknown",
		"Unknown",
		"Unknown",
		"Unknown",
		"Unknown",
		"Unknown",
		"Unknown",
		"L2",
		"R2",
		"L1",
		"R1",
		"Triangle",
		"Circle",
		"Cross",
		"Square",
		"Unknown",
		"Unknown",
		"Unknown",
		"Unknown",
		"Unknown",
		"Unknown",
		"Unknown"
	},
	digital = {
	}
};

for i=1,200 do
	tbl.digital[i] = "Unknown";
end

tbl.digital[1] = "A";
tbl.digital[2] = "B";
tbl.digital[3] = "X";
tbl.digital[4] = "Y";
tbl.digital[5] = "LB";
tbl.digital[6] = "RB";
tbl.digital[7] = "BACK";
tbl.digital[8] = "START";
tbl.digital[9] = "Lstick";
tbl.digital[10] = "Rstick";
tbl.digital[129] = "UP";
tbl.digital[130] = "DOWN";
tbl.digital[131] = "LEFT";
tbl.digital[132] = "RIGHT";


return "XBOX 360 For Windows (Controller)", tbl;
