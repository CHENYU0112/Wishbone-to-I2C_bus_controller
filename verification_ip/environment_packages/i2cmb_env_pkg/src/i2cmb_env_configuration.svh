class i2cmb_env_configuration extends ncsu_configuration;

  function new(string name="");
      super.new(name);
  endfunction

  virtual function string convert2string();
      return {super.convert2string};
  endfunction

  function string get_name();
    return name;
  endfunction

endclass
