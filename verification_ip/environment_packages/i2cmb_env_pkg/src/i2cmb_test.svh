class i2cmb_test extends ncsu_component #(.T(wb_transaction));

	i2cmb_env_configuration cfg;
	i2cmb_environment env;
	i2cmb_generator gen;
	string gen_type;

	function new(string name="", ncsu_component_base parent=null);
		super.new(name, parent);

		gen_type = "i2cmb_generator";
		ncsu_info("i2cmb_test::new()", $sformatf("found +GEN_TYPE=%s", gen_type),NCSU_NONE);

		// Initiates and construct environment configuration
		cfg = new(gen_type);

		// Initiates and construct environment
		env = new("env", this);
		env.set_configuration(cfg);
		env.build();

		// Initiates and construct generator
		$cast(gen, ncsu_object_factory::create(gen_type));
		gen.set_wb_agent(env.get_wb_agent());
		gen.set_i2c_agent(env.get_i2c_agent());
	endfunction

	virtual task run();
		// Run Environment and Generator
		env.run();
		gen.run();
	endtask

endclass
