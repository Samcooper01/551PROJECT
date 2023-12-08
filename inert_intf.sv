//////////////////////////////////////////////////////
// Interfaces with ST 6-axis inertial sensor.  In  //
// this application we only use Z-axis gyro for   //
// heading of mazeRunner.  Fusion correction     //
// comes from IR_Dtrm when en_fusion is high.   //
/////////////////////////////////////////////////
module inert_intf(clk,rst_n,strt_cal,cal_done,heading,rdy,IR_Dtrm,
                  SS_n,SCLK,MOSI,MISO,INT,moving,en_fusion);

	parameter FAST_SIM = 1;	// used to speed up simulation
	  
    input clk, rst_n;
    input MISO;								// SPI input from inertial sensor
	input INT;								// goes high when measurement ready
	input strt_cal;							// initiate claibration of yaw readings
	input moving;							// Only integrate yaw when going
	input en_fusion;						// do fusion corr only when forward at decent clip
	input [8:0] IR_Dtrm;					// derivative term of IR sensors (used for fusion)
	  
	output cal_done;						// pulses high for 1 clock when calibration done
	output signed [11:0] heading;			// heading of robot.  000 = Orig dir 3FF = 90 CCW 7FF = 180 CCW
	output rdy;								// goes high for 1 clock when new outputs ready (from inertial_integrator)
	output SS_n,SCLK,MOSI;					// SPI outputs

	// internal signals
	logic INT_ff1, INT_ff2;					// for double flopping INT
	logic [15:0] timer;						// 16-bit timer
	  
	// SM outputs
	logic C_Y_L, C_Y_H;						// capture yaw low/high
	logic wrt;								// assert for SPI to write
	logic [15:0] cmd;						// command to send to SPI
	logic vld;								// assert when data is valid

	// other internal signals
	logic done;
	logic [15:0] inert_data;					// Data back from inertial sensor (only lower 8-bits used)
	logic signed [15:0] yaw_rt;
	logic [7:0] yaw_h;
	logic [7:0] yaw_l;
	  
	// sm states
	typedef enum logic [2:0] {INIT1, INIT2, INIT3, WAITINT, YAWL, YAWH, ASSERTVAL} state_t;
	state_t state, next_state;
	  
	// SPI monarch module instantiation
	SPI_mnrch iSPI(.clk(clk),.rst_n(rst_n),.SS_n(SS_n),.SCLK(SCLK),
					 .MISO(MISO),.MOSI(MOSI),.wrt(wrt),.done(done),
					 .rd_data(inert_data),.wrt_data(cmd));
					  
	// instantiate the intertial integrator
	inertial_integrator #(FAST_SIM) iINT(.clk(clk), .rst_n(rst_n), .strt_cal(strt_cal),
						  .vld(vld),.rdy(rdy),.cal_done(cal_done), .yaw_rt(yaw_rt),.moving(moving),
						  .en_fusion(en_fusion),.IR_Dtrm(IR_Dtrm),.heading(heading));

	// double flop INT because intertial integrator is asynch to our clock
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			INT_ff2 <= 1'b0;
			INT_ff1 <= 1'b0;
		end
		else begin
			INT_ff2 <= INT_ff1;
			INT_ff1 <= INT;
		end
	end
	
	// 16-bit timer to wait for integrator to be ready
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			timer <= 16'h0000;
		else
			timer <= timer + 1;
	end
	
	// holding register for yaw_l
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			yaw_l <= 8'h00;
		else if (C_Y_L)
			yaw_l <= inert_data[7:0];
	end
	
	// holding register for yaw_h
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			yaw_h <= 8'h00;
		else if (C_Y_H)
			yaw_h <= inert_data[7:0];
	end
	
	// yaw_rt needs to be concat of yaw_h and yaw_l
	assign yaw_rt = {yaw_h, yaw_l};
	
	// sm register
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= INIT1;
		else
			state <= next_state;
	end
	
	// the SM
	always_comb begin
		// default outputs
		wrt = 0;
		cmd = 16'h0000;
		vld = 0;
		C_Y_L = 0;
		C_Y_H = 0;
		next_state = state;
		
		case (state)
			INIT1: begin
				cmd = 16'h0D02;
				if (&timer) begin
					wrt = 1;
					next_state = INIT2;
				end
			end
			
			INIT2: begin
				cmd = 16'h1160;
				if (done) begin
					wrt = 1;
					next_state = INIT3;
				end
			end
			
			INIT3: begin
				cmd = 16'h1440;
				if (done) begin	
					wrt = 1;
					next_state = WAITINT;
				end
			end
			
			WAITINT: begin
				cmd = 16'hA6xx;
				if (INT_ff2) begin
					wrt = 1;
					next_state = YAWL;
				end
			end
			
			YAWL: begin
				cmd = 16'hA7xx;
				if (done) begin
					wrt = 1;
					C_Y_L = 1;
					next_state = YAWH;
				end
			end
			
			YAWH: begin
				if (done) begin
					C_Y_H = 1;
					next_state = ASSERTVAL;
				end
			end
			
			ASSERTVAL: begin
				vld = 1;
				next_state = WAITINT;
			end
			
			default: next_state = INIT1;
		endcase
	end
	
endmodule
	  