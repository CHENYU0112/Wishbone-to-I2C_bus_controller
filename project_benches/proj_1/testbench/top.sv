`timescale 1ns / 10ps



module top();

parameter int WB_ADDR_WIDTH = 2;
parameter int WB_DATA_WIDTH = 8;

// ****************************************************************************
// define your parameter below

parameter int CLK_PERIOD = 10;
parameter int RESET_DELAY = 113;

parameter int NUM_I2C_BUSSES = 1;
parameter int I2C_ADDR_WIDTH = 7;
parameter int I2C_DATA_WIDTH = 8;
parameter int I2C_SLAVE_ADDRESS = 7'h22;
parameter int I2C_BUS_ID = 8'h05;  // Set desired I2C bus.

parameter int TEST_COUNT_1 = 32;
parameter int TEST_COUNT_2 = 32;
parameter int TEST_COUNT_3 = 64;

// ****************************************************************************
// Define variable



bit  clk;
bit  rst = 1'b1;
wire cyc;
wire stb;
wire we;
// tri ack;
tri1 ack;
// These nets are used to model resistive pulldown and pullup devices. If a tri0 net has no driver its value is 0. If a tri1 net has no driver, then its value is 1. These values have pull strength.
wire [WB_ADDR_WIDTH-1:0] adr;
wire signed[WB_DATA_WIDTH-1:0] dat_wr_o;
wire signed[WB_DATA_WIDTH-1:0] dat_rd_i;
wire irq;
tri  [NUM_I2C_BUSSES-1:0] scl;
tri  [NUM_I2C_BUSSES-1:0] sda;

// ****************************************************************************
//  Define Your Data Type below

enum bit {
    OP_READ     = 1,
    OP_WRITE    = 0
} i2c_op_t;



enum logic [1:0] {
  CSR  = 2'b00, // Control/Status Register
  DPR  = 2'b01, // Data/Parameter Register
  CMDR = 2'b10, // Command Register
  FSMR = 2'b11, // FSM States Register
  X    = 2'bxx
} Registers_Type;



enum logic [2:0] {
    CMD_SET_BUS     = 3'b110,
    CMD_START       = 3'b100,
    CMD_WRITE       = 3'b001,
    CMD_STOP        = 3'b101,
    CMD_READ_W_NAK  = 3'b011,
    CMD_READ_W_AK   = 3'b010,
    CMD_WAIT        = 3'b000,
    XX              = 3'bxxx
} CMD_Type;



enum logic[7:0] 
{
  START_BLC  = 8'bxxxxx100, // If bus is not captured yet: issue Start Condition and capture selected bus. If bus captured: issue Repeated Start Condition.
  STOP_BLC  = 8'bxxxxx101,  // Issue Stop Condition and free selected bus.
  READ_W_ACK_BLC = 8'bxxxxx010, // Receive a byte with acknowledge.
  READ_W_NACK_BLC = 8'bxxxxx011,  // Receive a byte with not-acknowledge.
  WRITE_BLC = 8'bxxxxx001,  // Transmit the byte given as a parameter.
  SET_BUS_BLC = 8'bxxxxx110,  // Connect to the specified bus (select bus).
  WAIT_BLC = 8'bxxxxx000  // Do nothing for specified amount of time.
} Byte_Level_Cmd;



// message print out setting
typedef enum bit
{
  TRUE = 1,
  FALSE = 0
} flag_bool;

flag_bool wb_print_enable = FALSE;
flag_bool wb_debug_enable = FALSE;
flag_bool i2c_print_enable = TRUE;
flag_bool i2c_debug_enable = FALSE;


// ****************************************************************************
// Instantiate the I2C slave Bus Functional Model
i2c_if      #(
    .I2C_ADDR_WIDTH(I2C_ADDR_WIDTH),
    .I2C_DATA_WIDTH(I2C_DATA_WIDTH),
    .SLAVE_ADDRESS(I2C_SLAVE_ADDRESS)
)
i2c_bus (
  // Slave signals
  .scl_s(scl[0]),
  .sda_s(sda[0])
);
// ****************************************************************************
// Instantiate the Wishbone master Bus Functional Model
wb_if       #(
      .ADDR_WIDTH(WB_ADDR_WIDTH),
      .DATA_WIDTH(WB_DATA_WIDTH)
)
wb_bus (
  // System sigals
  .clk_i(clk),
  .rst_i(rst),
  // Master signals
  .cyc_o(cyc),
  .stb_o(stb),
  .ack_i(ack),
  .adr_o(adr),
  .we_o(we),
  // Slave signals
  .cyc_i(),
  .stb_i(),
  .ack_o(),
  .adr_i(),
  .we_i(),
  // Shred signals
  .dat_o(dat_wr_o),
  .dat_i(dat_rd_i)
  );


// ****************************************************************************
// Instantiate the DUT - I2C Multi-Bus Controller
\work.iicmb_m_wb(str) #(.g_bus_num(NUM_I2C_BUSSES)) DUT
  (
    // ------------------------------------
    // -- Wishbone signals:
    .clk_i(clk),         // in    std_logic;                            -- Clock
    .rst_i(rst),         // in    std_logic;                            -- Synchronous reset (active high)
    // -------------
    .cyc_i(cyc),         // in    std_logic;                            -- Valid bus cycle indication
    .stb_i(stb),         // in    std_logic;                            -- Slave selection
    .ack_o(ack),         //   out std_logic;                            -- Acknowledge output
    .adr_i(adr),         // in    std_logic_vector(1 downto 0);         -- Low bits of Wishbone address
    .we_i(we),           // in    std_logic;                            -- Write enable
    .dat_i(dat_wr_o),    // in    std_logic_vector(7 downto 0);         -- Data input
    .dat_o(dat_rd_i),    //   out std_logic_vector(7 downto 0);         -- Data output
    // ------------------------------------
    // ------------------------------------
    // -- Interrupt request:
    .irq(irq),           //   out std_logic;                            -- Interrupt request
    // ------------------------------------
    // ------------------------------------
    // -- I2C master interfaces:
    .scl_i(scl),         // in    std_logic_vector(0 to g_bus_num - 1); -- I2C Clock inputs
    .sda_i(sda),         // in    std_logic_vector(0 to g_bus_num - 1); -- I2C Data inputs
    .scl_o(scl),         //   out std_logic_vector(0 to g_bus_num - 1); -- I2C Clock outputs
    .sda_o(sda)          //   out std_logic_vector(0 to g_bus_num - 1)  -- I2C Data outputs
    // ------------------------------------
  );



// initial    $timeformat(-9, 2, " ns", 6);
initial $timeformat(-9, 0, " ns", 6);
// ****************************************************************************
// Clock generator
initial begin : clk_gen
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ****************************************************************************
// Reset generator
initial begin : rst_gen
    // #(RESET_DELAY) rst = 0;
    #(RESET_DELAY) rst = ~rst;
end

// ****************************************************************************
// Monitor Wishbone bus and display transfers in the transcript
initial begin : wb_monitoring
  logic [WB_ADDR_WIDTH-1:0] addr_wb;  // lower address bits
  logic [WB_DATA_WIDTH-1:0] data_wb;  // data
  logic we_wb; // write enable

  #(RESET_DELAY)
  forever begin
  // forever begin @(posedge cyc)
    wb_bus.master_monitor(addr_wb, data_wb, we_wb);

    if (wb_print_enable == TRUE)
    begin
      case(we_wb)
        1'b0: $display("WB_BUS WRITE Transfer: [%0t]",$time);
        1'b1: $display("WB_BUS READ Transfer: [%0t]",$time);
        default: $display("Error Transfer: [%0t]\n",$time);
      endcase
      $display(" Lower addr bit: %h\t data: %p\t write enable: %h", addr_wb, data_wb, we_wb);
      $display("---------------------------------------------");
    end
  end
end

// ****************************************************************************
// Define the flow of the simulation
task wait_done();
    logic [WB_DATA_WIDTH-1:0] data_p;

    wait(irq);
    // read CMDR to clear irq bit
    wb_bus.master_read(CMDR,data_p);
endtask



task wb_wait_done();
  logic [WB_DATA_WIDTH-1:0] data_temp;  // data

  wait(irq);  
  // Read CMDR to clear irq bit
  wb_bus.master_read(CMDR, data_temp);
  // $display("wb_wait_done wb_bus.master_write at %t.\n", $time);

  // Error and Arbitration Lost detection
  if(data_temp == 8'bxxx1xxxx)
    $display("Last command terminated with an error at [%0t].\n", $time);
  else if (data_temp == 8'bxx1xxxxx)
    $display("Arbitration lost detected at [%0t].\n", $time);

  // if(wb_debug_enable == TRUE) 
  //   $display("---------- wb_bus command complete at [%0t] ---------- \n", $time);
endtask



task wb_enable_iicmb();
  // Write byte “1xxxxxxx” to the CSR register. 
  // This sets first bit E to '1', enabling the core.
  // Also sets second bit IE to '1', enbaling the interrupt output.
  // wb_bus.master_write(CSR,8'b11xxxxxx);
  wb_bus.master_write(CSR,8'b11000000);
endtask



task wb_set_bus_id(input logic [WB_DATA_WIDTH-1:0] bus_id);
  // store parameter, I2C Bus ID = 5
  // wb_bus.master_write(DPR, 8'h05);
  wb_bus.master_write(DPR, bus_id);

  // Write byte “xxxxx110” to the CMDR. This is Set Bus command.
  // wb_bus.master_write(CMDR,8'bxxxxx110);
  wb_bus.master_write(CMDR, SET_BUS_BLC);
  wb_wait_done();

  if (wb_debug_enable == TRUE)
    $display("wb_bus set I2C bus ID to %h at %t.\n", bus_id, $time);
endtask



task wb_start();
  // Write byte “xxxxx100” to the CMDR. This is Start command.
  // wb_bus.master_write(CMDR,8'bxxxxx100);
  wb_bus.master_write(CMDR,START_BLC);
  wb_wait_done();

  if (wb_debug_enable == TRUE)
    $display("wb_bus sent START Byte-Level Command at %t.\n", $time);
endtask



task wb_stop();
  // Write byte “xxxxx101” to the CMDR. This is Stop command.
  // wb_bus.master_write(CMDR,8'bxxxxx101);
  wb_bus.master_write(CMDR, STOP_BLC);
  wb_wait_done();

  if (wb_debug_enable == TRUE)
    $display("wb_bus sent STOP Byte-Level Command at %t.\n", $time);
endtask



task wb_set_slave_addr_n_op(input logic [WB_DATA_WIDTH-1:0] addr);

  wb_bus.master_write(DPR, addr);

  // Write byte “xxxxx001” to the CMDR. This is Set Bus command.
  // wb_bus.master_write(CMDR,8'bxxxxx001);
  wb_bus.master_write(CMDR, WRITE_BLC);
  wb_wait_done();

  if (wb_debug_enable == TRUE)
    $display("wb_bus set I2C slave address to %h at %t.\n", addr, $time);
endtask



task wb_write(input logic [WB_DATA_WIDTH-1:0] data_w);
  // store parameter: slave address
  wb_bus.master_write(DPR, data_w);

  // Write command
  wb_bus.master_write(CMDR, WRITE_BLC);
  wb_wait_done();

  if(wb_debug_enable == TRUE) 
    $display("WB_BUS WRITE Transfer: [%0t]\n data : %d\n",$time, data_w );
endtask



task wb_read_w_ack(output logic [WB_DATA_WIDTH-1:0] data_r);

  wb_bus.master_write(CMDR, READ_W_ACK_BLC);
  wb_wait_done();

  wb_bus.master_read(DPR, data_r);

  if(wb_debug_enable == TRUE) 
    $display("WB_BUS READ ACK Transfer: [%0t]\n data : %d\n",$time, data_r );
endtask



task wb_read_w_nack(output logic [WB_DATA_WIDTH-1:0] data_r);

  wb_bus.master_write(CMDR, READ_W_NACK_BLC);
  wb_wait_done();

  wb_bus.master_read(DPR, data_r);

  if(wb_debug_enable == TRUE) 
    $display("WB_BUS READ NACK Transfer: [%0t]\n data : %d\n",$time, data_r );
endtask





initial begin : wb_driver
  @(negedge rst);
  repeat(3) @(posedge clk);

  wb_enable_iicmb();
  wb_set_bus_id(I2C_BUS_ID);

//=============================================================
//  Write 32 incrementing values, from 0 to 31, to the i2c_bus
//=============================================================

  wb_start();
  wb_set_slave_addr_n_op({I2C_SLAVE_ADDRESS, OP_WRITE});

  for(int i=0; i<TEST_COUNT_1; i++)
  begin
    wb_write(i);
    // wb_wait_done();
  end

  wb_stop();

//=============================================================
//  Read 32 values from the i2c_bus
//  -> Return incrementing data from 100 to 131
//=============================================================

  wb_start();
  wb_set_slave_addr_n_op({I2C_SLAVE_ADDRESS, OP_READ});

  for(int i=0; i<TEST_COUNT_2; i++)
  begin
    automatic bit [I2C_DATA_WIDTH-1:0] data;
    if (i<(TEST_COUNT_2-1))
      wb_read_w_ack(data);
    else if (i==(TEST_COUNT_2-1))
      wb_read_w_nack(data);
    else
      $display("Error occur during read 32 values from i2c bus.");
  end

  wb_stop();

//=============================================================
//  Alternate writes and reads for 64 transfers
//  -> Increment write data from 64 to 127
//  -> Decrement read data from 63 to 0
//=============================================================

  for(int i=0; i<TEST_COUNT_3; i++) 
  begin
    automatic bit [I2C_DATA_WIDTH-1:0] data;
    wb_start();
    wb_set_slave_addr_n_op({I2C_SLAVE_ADDRESS, OP_WRITE});
    wb_write(8'd64 + i);
    // wb_stop();
    wb_start();
    wb_set_slave_addr_n_op({I2C_SLAVE_ADDRESS, OP_READ});    
    if (i<(TEST_COUNT_3-1))
      wb_read_w_ack(data);
    else if (i==(TEST_COUNT_3-1))
      wb_read_w_nack(data);
    else
      $display("Error occur during alternate writes and reads for 64 transfers.");
  end
  wb_stop();

//=============================================================
//  Finish Project 1
//=============================================================

    #1000 $finish;

end







initial begin : i2c_monitoring
  bit [I2C_ADDR_WIDTH-1:0] addr_i2c;
  bit i2c_op;
  bit [I2C_DATA_WIDTH-1:0] data_i2c [];

  #(RESET_DELAY)
  forever begin
    i2c_bus.monitor(addr_i2c, i2c_op, data_i2c);
    if (i2c_print_enable == TRUE)
    begin
      case(i2c_op)
        1'b0: $display("I2C_BUS WRITE Transfer: [%0t]",$time);
        1'b1: $display("I2C_BUS READ Transfer: [%0t]",$time);
        default: $display("Error Transfer: [%0t]\n",$time);
      endcase
      $display(" addr: 7'h%h\t data: %p\t", addr_i2c, data_i2c);
      $display("---------------------------------------------");
    end
  end
end



initial begin : driver_i2c_bus
  bit i2c_op;
  bit [I2C_DATA_WIDTH-1:0] write_data [];
  bit [I2C_DATA_WIDTH-1:0] read_data [];
  bit transfer_complete;

//=============================================================
//  Write 32 incrementing values, from 0 to 31, to the i2c_bus
//=============================================================
  // slave wait for master write
  i2c_bus.wait_for_i2c_transfer(i2c_op, write_data);
  // foreach(write_data[i]) 
  //   if ( i < MAX_TEST_ROUND_1 ) 
  //     // assert( i != write_data[i] ) 
  //     //   $fatal("wrong write data!");
  //     assert( write_data[i] == i ) 
  //       begin end 
  //     else 
  //       $fatal("wrong write data!");

//=============================================================
//  Read 32 values from the i2c_bus
//  -> Return incrementing data from 100 to 131
//=============================================================

  read_data = new [TEST_COUNT_2];   // memory allocation

  // slave wait for master read
  i2c_bus.wait_for_i2c_transfer(i2c_op, write_data);
  if( i2c_op == OP_READ ) 
  begin
    for(int i=0; i<TEST_COUNT_2; i++)
    begin
      read_data[i] = 8'd100 + i;
    end
    
    i2c_bus.provide_read_data(read_data, transfer_complete);
  end

//=============================================================
//  Alternate writes and reads for 64 transfers
//  -> Increment write data from 64 to 127  (total 64 counts)
//  -> Decrement read data from 63 to 0     (total 64 counts)
//=============================================================

  read_data = new [1];    // memory allocation
  for(int i=0; i<TEST_COUNT_3; i++)
  begin
    // slave wait for master write
    i2c_bus.wait_for_i2c_transfer(i2c_op, write_data);

    // slave wait for master read
    i2c_bus.wait_for_i2c_transfer(i2c_op, write_data);
    read_data[0] = 8'd63 - i;
    i2c_bus.provide_read_data(read_data, transfer_complete);
  end

end

endmodule
