class AttrAccessorObject
  def self.my_attr_accessor(*names)
    
    names.each do |name|
      define_method(name) do
        self.instance_variable_get("@#{name}")
      end

      define_method("#{name}=") do |var|
        self.instance_variable_set("@#{name}", var)
      end 
    end

  end
end
