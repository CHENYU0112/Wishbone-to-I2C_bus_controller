class i2cmb_predictor extends ncsu_component#(.T(wb_transaction));

	ncsu_component#(i2c_transaction) sb0;
	i2cmb_env_configuration cfg0;
	i2c_transaction pred_i2c, empty_trans;

	//----------------------------------------------------------------------
	// DUT status simulator related signals
	bit [4-1:0] bus_id;
	bit cmd_w_flg [iicmb_reg_ofst_t]; // Write Command flag
	bit cmd_r_flg [iicmb_reg_ofst_t]; // Read Command flag

	logic [8-1:0] dpr_reg;
	CMDR_REG cmdr_reg;
	CSR_REG csr_reg;

	// BYTE_FSM_STATE state_c; // Current State
	// BYTE_FSM_STATE state_n; // Next State
	// FSMR_REG fsmr_reg; // ! only predict byte fsm state

	//----------------------------------------------------------------------
	// i2c transaction predictor related signals
	bit en_flg;
	bit start_flg;
	bit rd_flg;

	iicmb_reg_ofst_t    	wb_addr;
	iicmb_cmdr_t        	wb_cmd;
	wb_op_t             	wb_op;
	bit [WB_DATA_WIDTH-1:0]	wb_data;
	
	bit 					i2c_addr_flg;   // if an i2c transaction has recieved address, assert this flag.
	bit[I2C_DATA_WIDTH-1:0] data_buffer[$];



	function new(string name="", ncsu_component_base parent = null);
		super.new(name, parent);
		en_flg =0;
		start_flg =0;
		bus_id =0;
		i2c_addr_flg =0;

		// state_c = S_IDLE;
	endfunction



	function void set_configuration(i2cmb_env_configuration cfg);
		cfg0 = cfg;
	endfunction



	virtual function void set_scoreboard(ncsu_component#(i2c_transaction) scoreboard);
		this.sb0 = scoreboard;
	endfunction



	function void set_cmd_flg( wb_op_t op, iicmb_reg_ofst_t addr);
		cmd_r_flg[CSR] = (op==WB_READ)&&(addr==CSR);
		cmd_r_flg[DPR] = (op==WB_READ)&&(addr==DPR);
		cmd_r_flg[CMDR] = (op==WB_READ)&&(addr==CMDR);
		cmd_r_flg[FSMR] = (op==WB_READ)&&(addr==FSMR);

		cmd_w_flg[CSR] = (op==WB_WRITE)&&(addr==CSR);
		cmd_w_flg[DPR] = (op==WB_WRITE)&&(addr==DPR);
		cmd_w_flg[CMDR] = (op==WB_WRITE)&&(addr==CMDR);
		cmd_w_flg[FSMR] = (op==WB_WRITE)&&(addr==FSMR);
	endfunction



	// virtual function void nb_put(T trans);
	// 	$display({get_full_name()," ",trans.convert2string()});
	// 	sb0.nb_transport(trans, empty_trans);
	// endfunction



	virtual function void nb_put(T trans);
		if( trans.get_type_handle() == wb_transaction::get_type() )begin
			$cast(wb_op, trans.get_op());
			$cast(wb_addr, trans.get_addr());
			$cast(wb_data, trans.get_data_0());
			if(wb_addr==CMDR) wb_cmd = iicmb_cmdr_t'(wb_data[2:0]);
			set_cmd_flg(wb_op, wb_addr);
		end

		DUT_REG_simulator(trans);
		I2C_trans_predictor(trans);

	endfunction



	function void DUT_REG_simulator(T trans);
		if( trans.get_type_handle() == wb_transaction::get_type() )begin
			if(cmd_w_flg[DPR]) dpr_reg = wb_data;
			if(cmd_w_flg[CMDR]) cmdr_reg.cmd = wb_cmd;
			if(cmd_w_flg[CMDR] && (wb_data[2:0]==3'd7)) cmdr_reg.err = 1'b1;

			if(cmd_w_flg[CSR])begin
				csr_reg.e = wb_data[7];
				csr_reg.ie = wb_data[6];
			end
		end // end if wb trans type
	endfunction



	function void I2C_trans_predictor(T trans);
		if( trans.get_type_handle() == wb_transaction::get_type() )begin
			if( cmd_w_flg[CMDR] ) begin // write CMDR
				if( wb_cmd == CMD_WRITE ) begin
					assert( (!i2c_addr_flg) || (i2c_addr_flg && (pred_i2c.i2c_op==I2C_WRITE)) );

					// not yet recieved i2c address, recieve an i2c address
					if(!i2c_addr_flg) begin
						$cast( pred_i2c, ncsu_object_factory::create("i2c_transaction"));
						$cast( pred_i2c.i2c_op ,dpr_reg[0]);
						i2c_addr_flg=1;
						pred_i2c.i2c_addr = dpr_reg[7:1];

					// already recieve i2c address, recieve data byte
					end else if( pred_i2c.i2c_op == I2C_WRITE )
						data_buffer.push_back(dpr_reg);

				end
				// start read from i2c slave, must recieved an i2c address before!
				if( wb_cmd==CMD_READ_W_AK || wb_cmd==CMD_READ_W_NAK ) begin
					assert(i2c_addr_flg && (pred_i2c.i2c_op==I2C_READ));
					rd_flg = 1;
				end
				// match terminate conditions, terminate capture data and send whole transaction to scoreboard
				if( wb_cmd == CMD_START || wb_cmd == CMD_STOP ) begin
					if(i2c_addr_flg) begin
						void'(pred_i2c.set_data( data_buffer ));
						sb0.nb_transport( pred_i2c, empty_trans );
						data_buffer.delete;
					end
				end
			end // end if write CMDR

			else if( cmd_r_flg[DPR] ) begin
				// if generator requested a read command before and generator now read out DPR from DUT,
				// predictor observe DPR value from wishbone bus line (wb_data).
				if(rd_flg) data_buffer.push_back(wb_data);
				rd_flg = 0;
			end // end if read DPR

			//----------------------------------------------------------------------
			// finish all process of i2c trans predictor, update control flags
			if(cmd_w_flg[CMDR] && wb_cmd==CMD_START) begin   i2c_addr_flg=0; end
			if(cmd_w_flg[CMDR] && wb_cmd==CMD_STOP)  begin   i2c_addr_flg=0; end
		end
	endfunction

endclass
