class i2cmb_generator extends ncsu_component;
    `ncsu_register_object(i2cmb_generator)

    wb_agent wb_agt0;
    i2c_agent i2c_agt0;

    wb_transaction cmd_start_trans, cmd_stop_trans, cmd_en_trans, cmd_write_trans, cmd_wdata_trans[32+64];
    wb_transaction trans_r[iicmb_reg_ofst_t];
    wb_transaction trans_w[iicmb_reg_ofst_t];

    i2c_transaction i2c_write_trans, i2c_read_trans, i2c_read_trans_arr[1+64];

    bit [I2C_DATA_WIDTH-1:0] i2c_data [$];

    // ************************* new object *************************
    function new(string name="", ncsu_component_base parent=null);
        super.new(name,parent);

        create_wb_start_trans();
        create_wb_stop_trans();
        create_wb_en_trans();
        create_wb_trans_r();
        create_wb_trans_w();
        create_wb_write_trans();
        create_wb_wdata_trans();
        create_i2c_read_trans();
        create_i2c_write_trans();
        create_i2c_read_trans_arr();

    endfunction


    function void create_wb_start_trans;
        $cast(cmd_start_trans, ncsu_object_factory::create("wb_transaction"));
        void'(cmd_start_trans.set_op(WB_WRITE)); 
        void'(cmd_start_trans.set_addr(CMDR)); 
        void'(cmd_start_trans.set_data({5'b0,CMD_START}));	// Repeated START Command
    endfunction


    function void create_wb_stop_trans;
        $cast(cmd_stop_trans, ncsu_object_factory::create("wb_transaction"));
        void'(cmd_stop_trans.set_op(WB_WRITE)); 
        void'(cmd_stop_trans.set_addr(CMDR)); 
        void'(cmd_stop_trans.set_data(CMD_STOP));			// Stop Command
    endfunction


    function void create_wb_en_trans;
        $cast(cmd_en_trans, ncsu_object_factory::create("wb_transaction"));
        void'(cmd_en_trans.set_op(WB_WRITE)); 
        void'(cmd_en_trans.set_addr(CSR)); 
        void'(cmd_en_trans.set_data(CSR_E | CSR_IE));		// Enable Core
    endfunction


    function void create_wb_trans_r;
        for(int i=3; i>=0; i--) begin
            automatic iicmb_reg_ofst_t addr_ofst = iicmb_reg_ofst_t'(i);
            $cast(trans_r[addr_ofst], ncsu_object_factory::create("wb_transaction"));

            // fixed command
            void'(trans_r[addr_ofst].set_addr(addr_ofst)); void'(trans_r[addr_ofst].set_op(WB_READ));
        end
    endfunction


    function void create_wb_trans_w;
        for(int i=3; i>=0; i--) begin
            automatic iicmb_reg_ofst_t addr_ofst = iicmb_reg_ofst_t'(i);
            $cast(trans_w[addr_ofst], ncsu_object_factory::create("wb_transaction"));

            // half-fixed command, need assign wb_data while using
            void'(trans_w[addr_ofst].set_addr(addr_ofst)); void'(trans_w[addr_ofst].set_op(WB_WRITE));
        end
    endfunction


    function void create_wb_write_trans;
        $cast(cmd_write_trans, ncsu_object_factory::create("wb_transaction"));
        void'(cmd_write_trans.set_op(WB_WRITE));
        void'(cmd_write_trans.set_addr(CMDR));
        void'(cmd_write_trans.set_data({5'b0,CMD_WRITE}));	// Write Command
    endfunction


    function void create_wb_wdata_trans;
        // allocate test data sequence
        foreach(cmd_wdata_trans[i]) begin
            $cast(cmd_wdata_trans[i], ncsu_object_factory::create("wb_transaction"));
            void'(cmd_wdata_trans[i].set_addr(DPR));
            void'(cmd_wdata_trans[i].set_op(WB_WRITE));
        end
    endfunction



    function void create_i2c_read_trans;
        $cast(i2c_read_trans, ncsu_object_factory::create("i2c_transaction"));
        void'(i2c_read_trans.set_op(I2C_READ));
    endfunction



    function void create_i2c_write_trans;
        $cast(i2c_write_trans, ncsu_object_factory::create("i2c_transaction"));
        void'(i2c_write_trans.set_op(I2C_WRITE));
    endfunction



    function void create_i2c_read_trans_arr;
        $cast(i2c_read_trans_arr[0], ncsu_object_factory::create("i2c_transaction"));
        void'(i2c_read_trans_arr[0].set_op(I2C_READ));

        for(int i=0; i<64; i++) begin
            $cast(i2c_read_trans_arr[i+1], ncsu_object_factory::create("i2c_transaction"));
            void'(i2c_read_trans_arr[i+1].set_op(I2C_READ));
        end
    endfunction

    // **************************************************************



    function void set_wb_agent(wb_agent wb_agt);
        this.wb_agt0 = wb_agt;
    endfunction

    function void set_i2c_agent(i2c_agent i2c_agt);
        this.i2c_agt0 = i2c_agt;
    endfunction

    // **************************************************************



    virtual task run();

        //=============================================================
        //  Write 32 incrementing values, from 0 to 31, to the i2c_bus
        //=============================================================
        foreach(cmd_wdata_trans[i]) begin
            void'(cmd_wdata_trans[i].set_data( (i<32)? i : 32+i ));
        end

        //=============================================================
        //  Read 32 values from the i2c_bus
        //  -> Return incrementing data from 100 to 131
        //=============================================================
        for(int i=0; i<32; i++) begin
            i2c_data.push_back( 100+i ); // 100 ~ 131
        end

        void'(i2c_read_trans_arr[0].set_data(i2c_data));

        //=============================================================
        //  Alternate writes and reads for 64 transfers
        //  -> Increment write data from 64 to 127
        //  -> Decrement read data from 63 to 0
        //=============================================================
        for(int i=0; i<64; i++) begin
            i2c_data.delete;
            i2c_data.push_back( 63-i );    // 63 ~ 0
            void'(i2c_read_trans_arr[i+1].set_data(i2c_data));
        end

        fork
            begin   // i2c thread
                i2c_agt0.bl_put( i2c_write_trans ); // for 32 write
                i2c_agt0.bl_put( i2c_read_trans_arr[0] );   // for 32 read
                for(int i=0;i<64;i++) begin // for 64 write + read
                    i2c_agt0.bl_put( i2c_write_trans );
                    i2c_agt0.bl_put( i2c_read_trans_arr[i+1] );
                end
            end     // end i2c thread

            begin   // wb thread
                wb_agt0.bl_put( cmd_en_trans );									// Enable Core
                wb_agt0.bl_put( trans_w[DPR].set_data(I2C_BUS_ID) );			// Select Bus ID
                wb_agt0.bl_put( trans_w[CMDR].set_data({5'b0,CMD_SET_BUS}) );	// Set Bus

                $display("----------------------------------------------------------------");
                $display(" Write 32 incrementing values                                   ");
                $display(" -> From 0 to 31, to the i2c_bus                                ");
                $display("----------------------------------------------------------------");

                wb_agt0.bl_put( cmd_start_trans );		    // Repeated START Command
                WB_address( I2C_WRITE );					// Slave Address and R/W bit & Write Command
                for(int i=0; i<32; i++) begin           	// Send 32 Data Bytes from Wishbone
                    WB_write_byte( cmd_wdata_trans[i] );	// Send Data Byte & Write Command
                end
                wb_agt0.bl_put( cmd_stop_trans );		    // Stop Command

                $display("----------------------------------------------------------------");
                $display(" Read 32 values from the i2c_bus                                ");
                $display(" -> Return incrementing data from 100 to 131                    ");
                $display("----------------------------------------------------------------");

                wb_agt0.bl_put( cmd_start_trans );          // Repeated START Command
                WB_address( I2C_READ );                   	// Slave Address and R/W bit & Write Command
                for(int i=0; i<32; i++) begin           	// Send 32 bytes from I2C Slave
                    WB_read_byte( i==31 );              	// Read Command & Read out DPR
                end
                wb_agt0.bl_put( cmd_stop_trans );			//Stop Command

                $display("----------------------------------------------------------------");
                $display(" Alternate writes and reads for 64 transfers                    ");
                $display(" -> Increment write data from 64 to 127  (total 64 counts)      ");
                $display(" -> Decrement read data from 63 to 0     (total 64 counts)      ");
                $display("----------------------------------------------------------------");

                //Alternate Transfers
                for(int i=32; i<96; i++) begin
                    wb_agt0.bl_put( cmd_start_trans );     	// Repeated START Command
                    WB_address( I2C_WRITE );               	// Slave Address and R/W bit & Write Command
                    WB_write_byte( cmd_wdata_trans[i] );	// Send Data Byte & Write Command
                    wb_agt0.bl_put( cmd_start_trans );     	// Repeated START Command
                    WB_address( I2C_READ );                	// Slave Address and R/W bit & Write Command
                    WB_read_byte();                      	// Read Command & Read out DPR
                end // end for loop
                wb_agt0.bl_put( cmd_stop_trans );		//Stop Command

            end     // end wb thread
        join

        $display("----------------------------------------------------------------");
        $display(" Project 2 Finish                                               ");
        $display("----------------------------------------------------------------");

    endtask

    virtual task WB_address( input i2c_op_t i2c_op, input bit [6:0] _slave_addr_=I2C_SLAVE_ADDRESS );
        wb_agt0.bl_put(trans_w[DPR].set_data( ({1'b0,_slave_addr_}<<1) | bit'(i2c_op) ) ); //Slave Address and R/W bit
        wb_agt0.bl_put(cmd_write_trans); //Write Command
    endtask

    task WB_write_byte( input wb_transaction trans );
        wb_agt0.bl_put(trans);			//Send Data Byte
        wb_agt0.bl_put(cmd_write_trans); //Write Command
    endtask

    task WB_read_byte( input logic last=1  );
        wb_agt0.bl_put(trans_w[CMDR].set_data( {5'b0, CMD_READ_W_AK ^ last } ) ); //Read with NACK Command
        wb_agt0.bl_put_ref(trans_r[DPR]); //Read DPR
    endtask


endclass
