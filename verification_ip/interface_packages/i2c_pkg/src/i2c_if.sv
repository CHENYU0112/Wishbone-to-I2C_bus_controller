`timescale 1ns / 10ps

interface i2c_if       #(
    int I2C_ADDR_WIDTH = 7,
    int I2C_DATA_WIDTH = 8,
    int SLAVE_ADDRESS = 7'h22
)(
    // Slave signals
    input           scl_s,
    inout   triand  sda_s
);
    import i2c_pkg::*;
   /* typedef enum bit {
         I2C_READ    = 1,
         I2C_WRITE   = 0
     } i2c_op_t;*/

    // Global signals
    logic sda_ack       = 0;
    logic ack_drive     = 0;
    assign sda_s = sda_ack ? ack_drive : 'bz;
   
    // Flag variable for task wait_for_i2c_transfer, provide_read_data
    bit     flag_drive_start = 0;
    bit     flag_drive_stop  = 0;
    bit     flag_drive_data  = 0;

    // Flag variable for task monitor
    bit     flag_monitor_start = 0;
    bit     flag_monitor_stop  = 0;
    bit     flag_monitor_data  = 0;



    // Waits for and captures transfer start
    task wait_for_i2c_transfer (output i2c_op_t op, output bit [I2C_DATA_WIDTH-1:0] write_data []);
        automatic bit [I2C_ADDR_WIDTH-1:0]      addr_packed;
        automatic bit [I2C_DATA_WIDTH-1:0]      data_packed;
        automatic bit [I2C_DATA_WIDTH-1:0]      data_packet_buffer [$];
        automatic bit correct = 0;

        wait_for_start_cmd(flag_drive_start);
        // wait_for_start_cmd();
        get_addr(op, correct, addr_packed);
        send_ack(correct);

        if(!correct) 
        begin
            wait_for_stop_cmd(flag_drive_stop);
            // wait_for_stop_cmd();
        end

        else
        begin
            if(op == I2C_WRITE) 
            begin
                @(negedge scl_s) sda_ack = 0;

                do 
                begin
                    flag_drive_data = 0;
                    fork : fork_in_driver
                        begin   
                            wait_for_start_cmd(flag_drive_start);
                            // wait_for_start_cmd();
                            flag_drive_start = 1;
                        end

                        begin
                            wait_for_stop_cmd(flag_drive_stop);
                            // wait_for_stop_cmd();
                        end

                        begin
                            read_data(data_packed);
                            data_packet_buffer.push_back(data_packed);
                            flag_drive_data = 1;
                            send_ack(correct);
                            @(negedge scl_s) sda_ack = 0;
                        end
                    join_any
                    disable fork;

                end while(flag_drive_data);

                write_data = new [ data_packet_buffer.size() ];
                write_data = {>>{data_packet_buffer}};
            end
            
            else    // op == I2C_READ
            begin
                // Do nothing.
            end
        end
    endtask


    // Provides data for read operation
    task provide_read_data (input bit [I2C_DATA_WIDTH-1:0] read_data [], output bit transfer_complete);
        automatic bit ack = 0; // 0: ack, 1: nack

        foreach(read_data[i]) 
        begin
            send_read_data(read_data[i]);
            @(negedge scl_s) sda_ack <= 0;
            @(posedge scl_s) ack = !sda_s;

            // When a slave doesn’t acknowledge the slave address, the data line must be left HIGH by the slave. The master can then generate either a STOP condition to abort the transfer, or a repeated START condition to start a new transfer. 
            if(!ack)
            begin // if receive nack from I2C master, stop transfer
                fork
                    begin
                        wait_for_start_cmd(flag_drive_start);
                        // wait_for_start_cmd(); 
                        flag_drive_start = 1;
                    end

                    begin
                        wait_for_stop_cmd(flag_drive_stop);
                        // wait_for_stop_cmd();
                    end
                join_any

                disable fork;
                break;
            end
        end
        // if receive ack, transfer incomplete, else if Non send_acknowledge, transfer complete
        transfer_complete = !ack;
    endtask


    // Returns data observed
    task monitor (output bit [I2C_ADDR_WIDTH-1:0] addr, output i2c_op_t op, output bit [I2C_DATA_WIDTH-1:0] data []);
        automatic bit [I2C_DATA_WIDTH-1:0] data_packed;
        automatic bit [I2C_DATA_WIDTH-1:0] data_packet_buffer [$];
        automatic bit correct = 0;
        automatic bit ack = 0;

        wait_for_start_cmd(flag_monitor_start);
        // wait_for_start_cmd();
        get_addr(op, correct, addr);
        @(posedge scl_s);

        if(!correct) 
        begin
            wait_for_stop_cmd(flag_monitor_stop);
            // wait_for_stop_cmd();
        end
        
        else 
        begin
            automatic bit flag_stall = 0;

            do 
            begin
                flag_monitor_data = 0;
                fork : fork_in_monitor
                    begin   
                        wait(flag_stall); 
                        wait_for_start_cmd(flag_monitor_start); 
                        // wait_for_start_cmd();  
                        flag_monitor_start = 1;
                    end

                    begin   
                        wait(flag_stall); 
                        wait_for_stop_cmd(flag_monitor_stop); 
                        // wait_for_stop_cmd(); 
                    end

                    begin   
                        read_data(data_packed);
                        data_packet_buffer.push_back(data_packed);
                        @(posedge scl_s);
                        flag_monitor_data = 1;
                    end
                join_any

                disable fork_in_monitor;
                flag_stall = 1;

            end while(flag_monitor_data);
        end
        
        data = new [ data_packet_buffer.size() ];
        data = {>>{data_packet_buffer}};
    endtask



    // START condition: signals begin to transfer at this condition. 
    // A HIGH to LOW transition on the SDA line by master device while the SCL is HIGH. 
    // task wait_for_start_cmd( bit _flag_start_ ); // <-- Will caused problem
    task automatic wait_for_start_cmd(ref bit flag_start_);
        while(!flag_start_) @(negedge sda_s) 
            if(scl_s) 
            begin
                flag_start_ = 1'b1;
                // $display("_flag_start_ = 1'b1 at [%0t]", $time);
            end
        flag_start_ = 1'b0;
    endtask

//    task wait_for_start_cmd;
//       forever @(negedge sda_s) if (scl_s) break;
//    endtask



    // STOP condition: A LOW to HIGH transition on the SDA line by master device while SCL is HIGH     
    task automatic wait_for_stop_cmd(ref bit flag_stop_);
        while(!flag_stop_) @(posedge sda_s) 
            if(scl_s) 
            begin
                flag_stop_ = 1'b1;
                // $display("_flag_stop_ = 1'b1 at [%0t]", $time);
            end
        flag_stop_ = 1'b0;
    endtask

    // task wait_for_stop_cmd;
    //   forever @(posedge sda_s) if (scl_s) break;
    // endtask



    // After the START condition, a slave address is sent. This address is 7 bits long followed by an eighth bit which is a data direction bit (R/W), the bit of (R/W) is “Zero” which indicates a transmission (WRITE), if it’s “One” which indicates the master will read data from the slave. The 7-bit address determines which slave will be selected by master. When an address is sent, each device in a system compares the first seven bits after the START condition with its address. If they match, the device considers itself addressed by the master as a slave-receiver or slave-transmitter, depending on the R/W bit. 
    task automatic get_addr(output i2c_op_t op_, output bit correct_, output bit [I2C_ADDR_WIDTH-1:0] addr_packed_);
        automatic bit buffer[$];

        for (integer i = 0; i < I2C_ADDR_WIDTH; i++)
            @(posedge scl_s) buffer.push_back(sda_s); 

        addr_packed_ = {>>{buffer}};
        @(posedge scl_s) op_ = i2c_op_t'(sda_s);

        correct_ = 1'b1;
    endtask



    // The acknowledge-related clock pulse is generated by the master. The transmitter release the SDA line (HIGH) during the acknowledge clock pulse. The receiver must pull down the SDA line during the acknowledge clock pulse so that it remains stable LOW during the HIGH period of this clock pulse. 
    task automatic send_ack(input bit correct_);
        @(negedge scl_s) 
        begin 
            sda_ack <= correct_; 
            ack_drive <= 0; 
            // sda_ack = correct_; 
            // ack_drive = 0; 
        end
        
        @(posedge scl_s);
    endtask



    task automatic read_data(output bit [I2C_DATA_WIDTH-1:0] data_packed_);
        automatic bit buffer[$];

        for (integer i = 0; i < I2C_DATA_WIDTH; i++)
            @(posedge scl_s) buffer.push_back(sda_s); 

        data_packed_ = {>>{buffer}};
        //$display("data= %d",data_packed_);
    endtask



    task automatic send_read_data(input bit [I2C_DATA_WIDTH-1:0] read_data_);
        for(integer i = 0; i<I2C_DATA_WIDTH; i++) 
        begin
            @(negedge scl_s) 
            sda_ack <=1; 
            ack_drive <= read_data_[I2C_DATA_WIDTH-i-1];
            // $display("i = %d", i);
            // $display("I2C_DATA_WIDTH-i = %d", (I2C_DATA_WIDTH-i-1));
        end

        // foreach(read_data_[j]) 
        // begin
        //     @(negedge scl_s) 
        //     sda_ack <= 1; 
        //     ack_drive <= read_data_[j];
        //     $display("j = %d", j);
        // end
        
    endtask

    task automatic arb_lost_during_restart();
        automatic bit _op_;
        automatic bit _correct_;
        automatic bit _stall_ =0;
        automatic bit [I2C_ADDR_WIDTH-1:0]      _addr_packed_;
        automatic bit [I2C_DATA_WIDTH-1:0]      _data_packed_;


            // WaitStart( flg_start_1 );
            // GetAddr( _op_, _correct_, _addr_packed_ );
            wait_for_start_cmd(flag_drive_start);
            get_addr( _op_, _correct_, _addr_packed_);
            assert( _correct_ ) begin end else $fatal("[info][%t] WRONG I2C slave address!!!",$time);

            // Ack( _correct_ );
            send_ack(_correct_);

            if(!_correct_) begin
                // WaitStop( flg_stop_1 );
                wait_for_stop_cmd(flag_drive_stop);

            end else if( _op_ == I2C_WRITE ) begin
                @(negedge scl_s) sda_ack =0;

                // GetDataPacket( _data_packed_ );
                // Ack( _correct_ );
                read_data(_data_packed_);
                send_ack(_correct_);

                @(negedge scl_s) //sda_ack =0;
                sda_ack =1;
                ack_drive<=0;
                // flg_data_1 = 0;
                flag_drive_data = 0;

            end // end if op == I2C_WRITE
    endtask

    task arb_lost_during_write();
        automatic bit correct = 0;
        automatic bit stall = 0;
        automatic bit illegal_start_flg = 0;
        automatic bit op;
        automatic bit [I2C_DATA_WIDTH-1:0]      data_packed;
        automatic bit [I2C_ADDR_WIDTH-1:0]      addr_packed;
        automatic bit [I2C_DATA_WIDTH-1:0]      data_packet_buffer [$];

            // WaitStart( flg_start_1 );
            wait_for_start_cmd(flag_drive_start);

            repeat(I2C_ADDR_WIDTH) @(posedge scl_s) begin
                if(sda_s==1)begin // i2c slave dont care about i2c master, always pull down sda_s
                    sda_ack <=1;
                    ack_drive <=0;
                    break;
                end
            end
            //#1000 sda_ack <=0;
    endtask

    task arb_lost_during_read();
        automatic i2c_op_t _op_ ;
        automatic bit [I2C_DATA_WIDTH-1:0] dontcare_data [];
        wait_for_i2c_transfer ( _op_, dontcare_data );
        // i2c slave dont care about i2c master, always pull down sda_s
        @(negedge scl_s) sda_ack <=1; ack_drive<=0;
    endtask

    task reset();
        sda_ack <= 0;
        // flg_start_1<=0;
        flag_drive_start <= 0;
    endtask
endinterface
