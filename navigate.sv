module navigate(clk,rst_n,strt_hdng,strt_mv,stp_lft,stp_rght,mv_cmplt,hdng_rdy,moving,
                en_fusion,at_hdng,lft_opn,rght_opn,frwrd_opn,frwrd_spd);
				
  parameter FAST_SIM = 1;		// speeds up incrementing of frwrd register for faster simulation
				
  input clk,rst_n;					// 50MHz clock and asynch active low reset
  input strt_hdng;					// indicates should start a new heading
  input strt_mv;					// indicates should start a new forward move
  input stp_lft;					// indicates should stop at first left opening
  input stp_rght;					// indicates should stop at first right opening
  input hdng_rdy;					// new heading reading ready....used to pace frwrd_spd increments
  output logic mv_cmplt;			// asserted when heading or forward move complete
  output logic moving;				// enables integration in PID and in inertial_integrator
  output en_fusion;					// Only enable fusion (IR reading affect on nav) when moving forward at decent speed.
  input at_hdng;					// from PID, indicates heading close enough to consider heading complete.
  input lft_opn,rght_opn,frwrd_opn;	// from IR sensors, indicates available direction.  Might stop at rise of lft/rght
  output reg [10:0] frwrd_spd;		// unsigned forward speed setting to PID
  
  logic lft_opn_rise, rght_opn_rise; // edges
  logic nxt_opn_lft, nxt_opn_rght; // next opn signal after flop
  logic curr_opn_lft, curr_opn_rght; // first open signal before flop
  logic [6:0] frwrd_inc; // rate of increment/decrement of frwrd_spd
  
  // state machine stuff
  logic init_frwrd;
  logic inc_frwrd;
  logic dec_frwrd;
  logic dec_frwrd_fast;
  typedef enum logic [2:0] { IDLE, HDNG, MV, DEC_FST, DEC_SLW } state_t;
  state_t state, next_state;
  
  localparam MAX_FRWRD = 11'h2A0;		// max forward speed
  localparam MIN_FRWRD = 11'h0D0;		// minimum duty at which wheels will turn
  localparam MAX_FRWRD_INC = 6'h18; 	// max increment for forward speed
  localparam MIN_FRWRD_INC = 6'h02;		// min increment for forward speed
  
  ////////////////////////////////
  // Now form forward register //
  //////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin
    if (!rst_n)
	  frwrd_spd <= 11'h000;
	else if (init_frwrd)		// assert this signal when leaving IDLE due to strt_mv
	  frwrd_spd <= MIN_FRWRD;									// min speed to get motors moving
	else if (hdng_rdy && inc_frwrd && (frwrd_spd<MAX_FRWRD))	// max out at 2A0
	  frwrd_spd <= frwrd_spd + {5'h00,frwrd_inc};				// always accel at 1x frwrd_inc
	else if (hdng_rdy && (frwrd_spd>11'h000) && (dec_frwrd | dec_frwrd_fast))
	  frwrd_spd <= ((dec_frwrd_fast) && (frwrd_spd>{2'h0,frwrd_inc,3'b000})) ? frwrd_spd - {2'h0,frwrd_inc,3'b000} : // 8x accel rate
                    (dec_frwrd_fast) ? 11'h000 :	  // if non zero but smaller than dec amnt set to zero.
	                (frwrd_spd>{4'h0,frwrd_inc,1'b0}) ? frwrd_spd - {4'h0,frwrd_inc,1'b0} : // slow down at 2x accel rate
					11'h000;
	end

	// rising edge detector nxt_lft
	always_ff @(posedge clk) begin
		nxt_opn_lft <= curr_opn_lft;
		curr_opn_lft <= lft_opn;
	end
	and rising_edge_left(lft_opn_rise, ~nxt_opn_lft, curr_opn_left);
	
	// rising edge detector nxt_rght
	always_ff @(posedge clk) begin
		nxt_opn_rght <= curr_opn_rght;
		curr_opn_rght <= rght_opn;
	end
	and rising_edge_right(rght_opn_rise, ~nxt_opn_rght, curr_opn_rght);
	
	generate if (FAST_SIM)
		assign frwrd_inc = MAX_FRWRD_INC;
	else
		assign frwrd_inc = MIN_FRWRD_INC;
	endgenerate
	
	// control en_fusion so that IR sensor only affects nav if moving forward
	assign en_fusion = (frwrd_spd > (MAX_FRWRD / 2));
	
	// handle moving to next state
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= next_state;
	end
	
	// SM
	always_comb begin
		// default outputs
		moving = 0;
		init_frwrd = 0;
		inc_frwrd = 0;
		dec_frwrd = 0;
		dec_frwrd_fast = 0;
		mv_cmplt = 0;
		next_state = state;
		
		// cases
		case (state)
			HDNG:
				if (!at_hdng)
					moving = 1;
				else begin
					mv_cmplt = 1;
					next_state = IDLE;
				end
			MV: begin
				inc_frwrd = 1;
				if (!frwrd_opn)
					next_state = DEC_FST;
				else if ((lft_opn_rise && stp_lft) || (rght_opn_rise && stp_rght))
					next_state = DEC_SLW;
				else begin
					moving = 1;
				end
				end
			DEC_SLW:
				if (frwrd_spd == 0) begin
					mv_cmplt = 1;
					next_state = IDLE;
				end
				else begin
					dec_frwrd = 1;
					moving = 1;
				end
			DEC_FST:
				if (frwrd_spd == 0) begin
					mv_cmplt = 1;
					next_state = IDLE;
				end	
				else begin
					dec_frwrd_fast = 1;
					moving = 1;
				end
			// default state is IDLE
			default:
				if (!rst_n)
					next_state = IDLE;
				else if (strt_hdng) begin
					moving = 1;
					next_state = HDNG;
				end
				else if (strt_mv) begin
					moving = 1;
					init_frwrd = 1;
					next_state = MV;
				end
		endcase
	end
	
	
endmodule
  