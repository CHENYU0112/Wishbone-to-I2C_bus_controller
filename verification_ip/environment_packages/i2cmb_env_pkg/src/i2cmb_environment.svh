class i2cmb_environment extends ncsu_component;

	i2cmb_env_configuration cfg0;
	wb_configuration wb_cfg0;
	i2c_configuration i2c_cfg0;

	wb_agent wb_agt0;
	i2c_agent i2c_agt0;
	i2cmb_predictor pred0;
	i2cmb_scoreboard sb0;
	i2cmb_coverage_wb wb_cov0;
	i2cmb_coverage_i2c i2c_cov0;

	function new(string name="", ncsu_component_base parent=null);
		super.new(name, parent);
	endfunction

	function void set_configuration(i2cmb_env_configuration cfg);
		cfg0 = cfg;
		wb_cfg0 = new(cfg.get_name());
		i2c_cfg0 = new(cfg.get_name());
	endfunction


	virtual function void build();
		wb_agt0 = new("wb_agent", this);
		wb_agt0.set_configuration(wb_cfg0);
		wb_agt0.build();
		wb_cov0 = new("wb_coverage", this);
		wb_cov0.set_configuration(cfg0);
		wb_cov0.build();

		i2c_agt0 = new("i2c_agent", this);
		i2c_agt0.set_configuration(i2c_cfg0);
		i2c_agt0.build();
		i2c_cov0 = new("i2c_coverage", this);
		i2c_cov0.set_configuration(cfg0);
		i2c_cov0.build();

		pred0 = new("predictor", this);
		pred0.set_configuration(cfg0);
		pred0.build();

		sb0 = new("scoreboard", this);
		sb0.build();

		i2c_agt0.connect_subscriber(sb0);
		i2c_agt0.connect_subscriber(i2c_cov0);

		wb_agt0.connect_subscriber(wb_cov0);
		wb_agt0.connect_subscriber(pred0);

		pred0.set_scoreboard(sb0);
	endfunction



	function wb_agent get_wb_agent();
		return wb_agt0;
	endfunction



	function i2c_agent get_i2c_agent();
		return i2c_agt0;
	endfunction



	virtual task run();
		wb_agt0.run();
		i2c_agt0.run();
		
		fork 
			sb0.run(); 
		join_none
	endtask

endclass
