parameter bit [7:0] I2C_BUS_ID = 8'h05;
parameter int NUM_I2C_BUSSES = 13;

typedef enum bit [3:0] {
       S_IDLE           = 4'd0,
       S_BUS_TAKEN      = 4'd1,
       S_START_PENDING  = 4'd2,
       S_START          = 4'd3,
       S_STOP           = 4'd4,
       S_WRITE_BYTE     = 4'd5,
       S_READ_BYTE      = 4'd6,
       S_WAIT           = 4'd7
} BYTE_FSM_STATE;

// ****************************************************************************
// Define register structure

typedef struct{
    bit don;    // Bit 7. Done bit. '0' = FSMs are busy. '1' = Command completed normally.
    bit nak;    // Bit 6. Data write was not acknowledged.
    bit al;     // Bit 5. Arbitration Lost.
    bit err;    // Bit 4. Error indication.
    bit r;      // Bit 3. Reserved bit.
    iicmb_cmdr_t cmd;   // Bit 2 ~ 0. Byte-level command code. 
} CMDR_REG;

typedef struct{
    bit e;      // Bit 7. '0' = IICMB is disabled; '1' = IICMB is enabled.
    bit ie;     // Bit 6. '0' = irq output is disabled; '1' = irq output is enabled.
    bit bb;     // Bit 5. '0' = Selected bus is idle; '1' = Selected bus is busy.
    bit bc;     // Bit 4. '0' = Selected bus isn't captured by IICMB. 
                //        '1' = Selected bus is captured by IICMB.
    bit [3:0] bus_id;   // Bit 3 ~ 0.  Bus ID. 
} CSR_REG;

typedef struct{
    BYTE_FSM_STATE   byte_fsm;  // Bit 7 ~ 4: Current state of Byte-level FSM.
    bit [3:0]   bit_fsm;        // Bit 3 ~ 0: Current state of Bit-level FSM.
} FSMR_REG;

string map_state_name[ BYTE_FSM_STATE ] = '{
    S_IDLE: "S_IDLE",
    S_BUS_TAKEN: "S_BUS_TAKEN"
};
