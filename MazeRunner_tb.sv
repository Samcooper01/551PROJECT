module MazeRunner_tb();
  
  reg clk,RST_n;				// clock and reset
  reg send_cmd;					// assert to send command to MazeRunner_tb
  reg [15:0] cmd;				// 16-bit command to send
  reg [11:0] batt;				// battery voltage 0xDA0 is nominal
  
  logic cmd_sent;				// high when command is sent
  logic resp_rdy;				// MazeRunner has sent a pos acknowledge
  logic [7:0] resp;				// resp byte from MazeRunner (hopefully 0xA5)
  logic hall_n;					// magnet found?
  logic piezo_n, piezo;			// for checking piezo functionality
  
  /////////////////////////////////////////////////////////////////////////
  // Signals interconnecting MazeRunner to RunnerPhysics and RemoteComm //
  ///////////////////////////////////////////////////////////////////////
  wire TX_RX,RX_TX;
  wire INRT_SS_n,INRT_SCLK,INRT_MOSI,INRT_MISO,INRT_INT;
  wire lftPWM1,lftPWM2,rghtPWM1,rghtPWM2;
  wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;
  wire IR_lft_en,IR_cntr_en,IR_rght_en;  
  
  localparam FAST_SIM = 1'b0;
  localparam HEADING_MAX = 12'hFFF;

  //////////////////////
  // Instantiate DUT //
  ////////////////////
  MazeRunner iDUT(.clk(clk),.RST_n(RST_n),.INRT_SS_n(INRT_SS_n),.INRT_SCLK(INRT_SCLK),
                  .INRT_MOSI(INRT_MOSI),.INRT_MISO(INRT_MISO),.INRT_INT(INRT_INT),
				  .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
				  .A2D_MISO(A2D_MISO),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
				  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),.RX(RX_TX),.TX(TX_RX),
				  .hall_n(hall_n),.piezo(piezo),.piezo_n(piezo_n),.IR_lft_en(IR_lft_en),
				  .IR_rght_en(IR_rght_en),.IR_cntr_en(IR_cntr_en),.LED());
	
  ///////////////////////////////////////////////////////////////////////////////////////
  // Instantiate RemoteComm which models bluetooth module receiving & forwarding cmds //
  /////////////////////////////////////////////////////////////////////////////////////
  RemoteComm iCMD(.clk(clk), .rst_n(RST_n), .RX(TX_RX), .TX(RX_TX), .cmd(cmd), .send_cmd(send_cmd),
               .cmd_sent(cmd_sent), .resp_rdy(resp_rdy), .resp(resp));
			   
				  
  RunnerPhysics iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(INRT_SS_n),.SCLK(INRT_SCLK),.MISO(INRT_MISO),
                      .MOSI(INRT_MOSI),.INT(INRT_INT),.lftPWM1(lftPWM1),.lftPWM2(lftPWM2),
					  .rghtPWM1(rghtPWM1),.rghtPWM2(rghtPWM2),
                     .IR_lft_en(IR_lft_en),.IR_cntr_en(IR_cntr_en),.IR_rght_en(IR_rght_en),
					 .A2D_SS_n(A2D_SS_n),.A2D_SCLK(A2D_SCLK),.A2D_MOSI(A2D_MOSI),
					 .A2D_MISO(A2D_MISO),.hall_n(hall_n),.batt(batt));
	
	// SIGNALS TO CHECK
  // INPUTS TO DUT: cmd, send_cmd, batt, hall_n, clk, rst_n
  // OUTPUTS FROM DUT: resp, resp_rdy, cmd_sent, piezo_n, piezo
  // RUNNER PHYSICS INTERNAL SIGNALS: heading_robot[19:8], xx[14:12], yy[14:12] for positions, magnet_xx_pos, magnet_yy_pos (can change)

  initial begin
	  batt = 12'hDA0;  	// this is value to use with RunnerPhysics
    cmd = 16'h0000;
    send_cmd = 1'b0;
    //rst_n = 1'b1;
    clk = 1'b0;
    // hall_n maybe

    // TEST 1: takes right path to magnet manually
    //@(negedge clk) rst_n = 0;
    //@(negedge clk) rst_n = 1;

    // send calibrate command, check for pos ack
    cmd = 16'h0000;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // wait for cmd_sent
    fork
      begin: to1
        repeat(2560000) @(posedge clk);
        $display("ERR: timed out waiting for cmd_sent in to1\n");
        $stop();
      end: to1
      begin
        @(posedge cmd_sent);
        disable to1;
        $display("GOOD: received cmd_sent in to1\n");
      end
    join

    // wait for resp_rdy and check
    fork
      begin: to2
        repeat(2560000) @(posedge clk);
        $display("ERR: timed out waiting for resp_rdy in to2\n");
        $stop();
      end: to2
      begin
        @(posedge resp_rdy);
        disable to2;
        $display("GOOD: received resp_rdy in tow");
        if (resp !== 8'hA5) begin
          $display("ERR: resp did not contain 0xA5 in to2\n");
          $stop();
        end
      end
    join

    // send heading command to north
    cmd = 16'h2000;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // wait for resp_rdy
    fork
      begin: to3
        repeat(2560000) @(posedge clk);
        $display("ERR: timed out waiting for resp_rdy in to3\n");
        $stop();
      end: to3
      begin
        @(posedge resp_rdy);
        disable to3;
        $display("GOOD: received resp_rdy in to3\n");
      end
    join

    // check that the robot has a proper heading after command was sent
    if (!((0.95 * HEADING_MAX) < iPHYS.heading_robot[19:8] || iPHYS.heading_robot[19:8] < (0.05 * HEADING_MAX))) begin
      $display("ERR: heading was not set properly, expected 0x000 and got %x\n", iPHYS.heading_robot[19:8]);
      $stop();
    end

    // send move command, stop at left
    cmd = 16'h4002;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // wait for resp_rdy
    fork
      begin: to4
        repeat(2560000) @(posedge clk);
        $display("ERR: timed out waiting for resp_rdy in to4\n");
        $stop();
      end: to4
      begin
        @(posedge resp_rdy);
        disable to4;
        $display("GOOD: received resp_rdy in to4\n");
      end
    join

    // check that the robot is in (2,1)
    if (iPHYS.xx[14:12] !== 2 || iPHYS.yy[14:12] !== 1) begin
      $display("ERR: robot is not in (2,1) after first move\n");
      $stop();
    end

    // change heading to left 
    cmd = 16'h23FF;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // switching to not forking on resp_rdy now
    @(posedge resp_rdy);

    // check if heading was updated properly
    if (!((0.70 * HEADING_MAX) < iPHYS.heading_robot[19:8] || iPHYS.heading_robot[19:8] < (0.80 * HEADING_MAX))) begin
      $display("ERR: heading was not set properly, expected 0x3FF and got %x\n", iPHYS.heading_robot[19:8]);
      $stop();
    end

    // send move command, stop at right
    cmd = 16'h4001;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // wait for done
    @(posedge resp_rdy);

    // check that the robot is in (1,1)
    if (iPHYS.xx[14:12] !== 1 || iPHYS.yy[14:12] !== 1) begin
      $display("ERR: robot is not in (1,1) after first move\n");
      $stop();
    end

    // send heading command to north
    cmd = 16'h2000;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // wait for resp_rdy
    @(posedge resp_rdy);

    // check that the robot has a proper heading after command was sent
    if (!((0.95 * HEADING_MAX) < iPHYS.heading_robot[19:8] || iPHYS.heading_robot[19:8] < (0.05 * HEADING_MAX))) begin
      $display("ERR: heading was not set properly, expected 0x000 and got %x\n", iPHYS.heading_robot[19:8]);
      $stop();
    end

    // send move command, stop at right
    cmd = 16'h4001;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // wait for done
    @(posedge resp_rdy);

    // check that the robot is in (1,2)
    if (iPHYS.xx[14:12] !== 1 || iPHYS.yy[14:12] !== 2) begin
      $display("ERR: robot is not in (1,2) after first move\n");
      $stop();
    end

    // change heading to east
    cmd = 16'h2C00;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // wait for resp_rdy
    @(posedge resp_rdy);

    // check if heading was updated properly
    if (!((0.20 * HEADING_MAX) < iPHYS.heading_robot[19:8] || iPHYS.heading_robot[19:8] < (0.30 * HEADING_MAX))) begin
      $display("ERR: heading was not set properly, expected 0xC00 and got %x\n", iPHYS.heading_robot[19:8]);
      $stop();
    end

    // send move command, stop at left
    cmd = 16'h4002;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // wait for done
    @(posedge resp_rdy);

    // check that the robot is in (3,2)
    if (iPHYS.xx[14:12] !== 3 || iPHYS.yy[14:12] !== 2) begin
      $display("ERR: robot is not in (3,2) after first move\n");
      $stop();
    end

    // send heading command to north
    cmd = 16'h2000;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // wait for resp_rdy
    @(posedge resp_rdy);

    // check that the robot has a proper heading after command was sent
    if (!((0.95 * HEADING_MAX) < iPHYS.heading_robot[19:8] || iPHYS.heading_robot[19:8] < (0.05 * HEADING_MAX))) begin
      $display("ERR: heading was not set properly, expected 0x000 and got %x\n", iPHYS.heading_robot[19:8]);
      $stop();
    end

    // send move command, stop at left
    cmd = 16'h4002;
    @(posedge clk) send_cmd = 1;
    @(posedge clk) send_cmd = 0;

    // wait for done
    @(posedge resp_rdy);

    // check that the robot is in (3,3)
    if (iPHYS.xx[14:12] !== 3 || iPHYS.yy[14:12] !== 3) begin
      $display("ERR: robot is not in (3,3) after first move\n");
      $stop();
    end

    // check for solve completed through piezo
    fork
      begin: to5
        repeat(2560000) @(posedge clk);
        $display("ERR: timed out waiting for piezo in to5\n");
        $stop();
      end: to5
      begin
        @(posedge piezo);
        disable to5;
        $display("GOOD: EUREKA! found the jawn\n");
      end
    join

  end
  
  always
    #5 clk = ~clk;
	
endmodule