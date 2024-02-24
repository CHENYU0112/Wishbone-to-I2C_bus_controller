`timescale 1ns / 10ps

module top();

parameter int WB_ADDR_WIDTH = 2;
parameter int WB_DATA_WIDTH = 8;
parameter int NUM_I2C_BUSSES = 1;

// generates a 10 ns clock
parameter int CLOCK_CYCLE = 10; 
// generates a 113 ns reset
parameter int RESET_DELAY = 113;

// message print out setting
typedef enum bit
{
  TRUE = 1,
  FALSE = 0
} flag_bool;

flag_bool print_enable = TRUE;



bit  clk;
bit  rst = 1'b1;
wire cyc;
wire stb;
wire we;
tri1 ack;
// tri ack;
wire [WB_ADDR_WIDTH-1:0] adr;
wire [WB_DATA_WIDTH-1:0] dat_wr_o;
wire [WB_DATA_WIDTH-1:0] dat_rd_i;
wire irq;
tri  [NUM_I2C_BUSSES-1:0] scl;
tri  [NUM_I2C_BUSSES-1:0] sda;


logic [WB_ADDR_WIDTH-1:0] addr_wb;  // lower address bits
logic [WB_DATA_WIDTH-1:0] data_wb;  // data
logic we_wb; // write enable

enum bit[1:0] 
{
  CSR  = 2'b00, 
  DPR  = 2'b01, 
  CMDR = 2'b10, 
  FSMR = 2'b11
} Registers;

// ****************************************************************************
// Clock generator
initial begin : clk_gen
  clk = 0;
  forever #(CLOCK_CYCLE/2) clk = ~clk;
end

// ****************************************************************************
// Reset generator
initial begin : rst_gen
  // rst = 1'b1;
  #(RESET_DELAY) rst = ~rst;
end

// ****************************************************************************
// Monitor Wishbone bus and display transfers in the transcript
initial begin : wb_monitoring
  // logic [WB_ADDR_WIDTH-1:0] addr_wb;  // lower address bits
  // logic [WB_DATA_WIDTH-1:0] data_wb;  // data
  // logic we_wb; // write enable

  forever begin @(posedge cyc)
    // $timeformat(-9, 2, " ns", 6);
    $timeformat(-9, 0, " ns", 6);
    wb_bus.master_monitor(addr_wb, data_wb, we_wb);
    if (print_enable == TRUE)
    begin
      $display("wb_bus.master_monitor at %t.", $time);
      // $display(" addr: %h\n data: %h\n write enable: %h\n", addr_wb, data_wb, we_wb);
      $display(" addr: %h\t data: %h\t write enable: %h\n", addr_wb, data_wb, we_wb);
    end
  end
end

// ****************************************************************************
// Define the flow of the simulation
initial begin : test_flow
  logic [WB_DATA_WIDTH-1:0] data_temp;  // data

  // Wait 200ns
  #200

  // Ex1 Task: Enable the IICMB core after power-up.
  // 1. Write byte “1xxxxxxx” to the CSR register. This sets bit E to '1', enabling the core.
  wb_bus.master_write(CSR,8'b11xxxxxx);

  // Wait 200ns
  #200

  // Ex3 Task: Write a byte 0x78 to a slave with address 0x22, residing on I2C bus #5.
  // 1. Write byte 0x05 to the DPR. This is the ID of desired I2C bus.
  $display("Ex3 Task - Step 1");
  wb_bus.master_write(DPR,8'h5);
  
  // 2. Write byte “xxxxx110” to the CMDR. This is Set Bus command.
  $display("Ex3 Task - Step 2");
  wb_bus.master_write(CMDR,8'bxxxxx110);
  
  // 3. Wait for interrupt or until DON bit of CMDR reads '1'.
  $display("Ex3 Task - Step 3");
  wait(irq);  wb_bus.master_read(CMDR,data_temp);
  
  // 4. Write byte “xxxxx100” to the CMDR. This is Start command.
  $display("Ex3 Task - Step 4");
  wb_bus.master_write(CMDR,8'bxxxxx100);
  
  // 5. Wait for interrupt or until DON bit of CMDR reads '1'.
  $display("Ex3 Task - Step 5");
  wait(irq);  wb_bus.master_read(CMDR,data_temp);
  
  // 6. Write byte 0x44 to the DPR. This is the slave address 0x22 shifted 1 bit to the left + rightmost bit = '0', which means writing.
  $display("Ex3 Task - Step 6");
  wb_bus.master_write(DPR,8'h44);

  // 7. Write byte “xxxxx001” to the CMDR. This is Write command.
  $display("Ex3 Task - Step 7");
  wb_bus.master_write(CMDR,8'bxxxxx001);

  // 8. Wait for interrupt or until DON bit of CMDR reads '1'. If instead of DON the NAK bit is '1', then slave doesn't respond.
  $display("Ex3 Task - Step 8");
  wait(irq);  wb_bus.master_read(CMDR,data_temp);

  // 9. Write byte 0x78 to the DPR. This is the byte to be written.
  $display("Ex3 Task - Step 9");
  wb_bus.master_write(DPR,8'h78);

  // 10.Write byte “xxxxx001” to the CMDR. This is Write command.
  $display("Ex3 Task - Step 10");
  wb_bus.master_write(CMDR,8'bxxxxx001);

  // 11.Wait for interrupt or until DON bit of CMDR reads '1'.
  $display("Ex3 Task - Step 11");
  wait(irq);  wb_bus.master_read(CMDR,data_temp);

  // 12.Write byte “xxxxx101” to the CMDR. This is Stop command.
  $display("Ex3 Task - Step 12");
  wb_bus.master_write(CMDR,8'bxxxxx101);

  // 13.Wait for interrupt or until DON bit of CMDR reads '1'.
  $display("Ex3 Task - Step 13");
  wait(irq);  wb_bus.master_read(CMDR,data_temp);

end

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
    // -- I2C interfaces:
    .scl_i(scl),         // in    std_logic_vector(0 to g_bus_num - 1); -- I2C Clock inputs
    .sda_i(sda),         // in    std_logic_vector(0 to g_bus_num - 1); -- I2C Data inputs
    .scl_o(scl),         //   out std_logic_vector(0 to g_bus_num - 1); -- I2C Clock outputs
    .sda_o(sda)          //   out std_logic_vector(0 to g_bus_num - 1)  -- I2C Data outputs
    // ------------------------------------
  );


endmodule
