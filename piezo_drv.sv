module piezo_drv(clk,rst_n,batt_low,fanfare,piezo,piezo_n);

input logic clk, rst_n, batt_low, fanfare;
output logic piezo, piezo_n;

logic [14:0] cnt_frq, frq;
logic [24:0] cnt_dur, dur;
logic rst_frq, rst_dur;

parameter FAST_SIM = 0;

typedef enum logic [3:0] {IDLE, G6, C7, E7, G7, E7_2, G7_2, BL_G6, BL_C7, BL_E7} state_t;
state_t state, nxtstate;

always_ff@(posedge clk, negedge rst_n/*, posedge rst_frq*/) begin
	if(!rst_n)
	cnt_frq <= 0;
	else if(rst_frq)
	cnt_frq <= 0;
	else
	cnt_frq <= cnt_frq + 1;
end
assign piezo = (cnt_frq >= (frq/2)) ? 1 : 0;
assign piezo_n = ~piezo;
assign rst_frq = (cnt_frq==frq) ? 1 : 0;

always_ff@(posedge clk, negedge rst_n/*, posedge rst_dur*/) begin
	if(!rst_n)
	cnt_dur <= 0;
	else if(rst_dur)
	cnt_dur <= 0;
	else begin
		if(FAST_SIM)
		cnt_dur <= cnt_dur+16;
		else
		cnt_dur <= cnt_dur+1;
	end
end

//SM FF
always_ff@(posedge clk, negedge rst_n) begin
if(!rst_n)
state <= IDLE;
else
state <= nxtstate;
end

always_comb begin
rst_dur = 0;
dur = 0;
frq = 0;
nxtstate = state;
case(state)
 IDLE : begin
 if(batt_low) begin
	nxtstate = BL_G6;
 end
 else if(fanfare) begin
	nxtstate = G6;
 end
 end
 G6 : begin
 frq = 31888;
 dur  = 8388608;
 if(cnt_dur == dur) begin
 rst_dur = 1;
 nxtstate = C7;
 end
 end
 C7 : begin
  frq = 23889;
 dur  = 8388608;
 if(cnt_dur == dur) begin
 rst_dur = 1;
 nxtstate = E7;
 end
 end
 E7 : begin
  frq = 18961;
 dur  = 8388608;
 if(cnt_dur == dur) begin
 rst_dur = 1;
 nxtstate = G7;
 end
 end
 G7 : begin
  frq = 15944;
 dur  = (8388608 + 4194304);
 if(cnt_dur == dur) begin
 rst_dur = 1;
 nxtstate = E7_2;
 end
 end
 E7_2 : begin
  frq = 18961;
 dur  = 4194304;
 if(cnt_dur == dur) begin
 rst_dur = 1;
 nxtstate = G7_2;
 end
 end
 G7_2 : begin
  frq = 15944;
 dur  = 16777216;
 if(cnt_dur == dur) begin
 rst_dur = 1;
 nxtstate = IDLE;
 end
 end
 BL_G6 : begin
 frq = 31888;
 dur  = 8388608;
 if(cnt_dur == dur) begin
 rst_dur = 1;
 nxtstate = BL_C7;
 end
 end
 BL_C7 : begin
 frq = 23889;
 dur  = 8388608;
 if(cnt_dur == dur) begin
 rst_dur = 1;
 nxtstate = BL_E7;
 end
 end
 BL_E7 : begin
 frq = 18961;
 dur  = 8388608;
 if(cnt_dur == dur) begin
 rst_dur = 1;
 nxtstate = IDLE;
 end
 end
 default : begin
	nxtstate = IDLE;
 end

endcase
end

endmodule
