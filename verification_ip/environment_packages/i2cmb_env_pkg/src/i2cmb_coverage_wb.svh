class i2cmb_coverage_wb extends ncsu_component #(.T(wb_transaction));

	i2cmb_env_configuration cfg0;

	function void set_configuration(i2cmb_env_configuration cfg);
		cfg0 = cfg;
	endfunction

	function new(string name= "", ncsu_component_base parent = null);
		super.new(name, parent);
	endfunction

	virtual function void nb_put(T trans);
	
	endfunction


endclass
