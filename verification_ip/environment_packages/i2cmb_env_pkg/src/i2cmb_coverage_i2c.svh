class i2cmb_coverage_i2c extends ncsu_component #(.T(i2c_transaction));

	i2cmb_env_configuration cfg0;

	// i2c_op_t i2c_op;
	// bit [I2C_ADDR_WIDTH-1:0] i2c_addr;
	// bit [I2C_DATA_WIDTH-1:0] i2c_data[];
	// int i2c_data_arr_size;
	// event sample_i2c;

	function void set_configuration(i2cmb_env_configuration cfg);
		cfg0 = cfg;
	endfunction

	function new(string name= "", ncsu_component_base parent = null);
		super.new(name, parent);
		// i2c_coverage = new;
	endfunction

	virtual function void nb_put(T trans);

	endfunction

endclass
