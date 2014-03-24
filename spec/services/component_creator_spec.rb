require 'spec_helper'

describe ComponentCreator do

  describe :set_manufacturer_key do
    it "should set the manufacturer if it finds it and set the set the foreign keys" do
      m = FactoryGirl.create(:manufacturer, name: "SRAM")
      c = { manufacturer: "sram" }
      component = ComponentCreator.new().set_manufacturer_key(c)
      component[:manufacturer_id].should eq(m.id)
      component[:manufacturer].should_not be_present
    end
    it "should add other manufacturer name and set the set the foreign keys" do
      m = FactoryGirl.create(:manufacturer, name: "Other")
      c = { manufacturer: "Gobbledy Gooky" }
      component = ComponentCreator.new().set_manufacturer_key(c)
      component[:manufacturer_id].should eq(m.id)
      component[:manufacturer].should_not be_present
      component[:manufacturer_other].should eq('Gobbledy Gooky')
    end
  end

  describe :set_component_type do 
    it "should set the component_type from a string" do 
      ctype = FactoryGirl.create(:ctype, name: "Stuff blows")
      c = { component_type: "sTuff Blows " }
      component = ComponentCreator.new().set_component_type(c)
      component[:ctype_id].should eq(ctype.id)
      component[:component_type].should_not be_present
    end
    it "should create a new component type if we don't recognize it" do 
      ctype = FactoryGirl.create(:ctype, name: "Unknown")
      c = { component_type: "Hubs" }
      component = ComponentCreator.new().set_component_type(c)
      component[:ctype_id].should eq(ctype.id)
      component[:ctype_other].should eq('Hubs')
      component[:component_type].should_not be_present
    end
  end

  describe :create_component do 
    it "should create the component" do 
      bike = FactoryGirl.create(:bike)
      component = {description: "Stuff"}
      component_creator = ComponentCreator.new(bike: bike)
      component_creator.create_component(component)
      bike.reload.components.count.should eq(1)
    end
    it "should create the component and ignore attributes it shouldn't use" do 
      bike = FactoryGirl.create(:bike)
      component = {description: "Stuff", cgroup: "Drivetrain and brakes"}
      component_creator = ComponentCreator.new(bike: bike)
      component_creator.create_component(component)
      bike.reload.components.count.should eq(1)
    end
  end

  describe :create_components_from_params do 
    it "should return nil if there are no components" do 
      b_param = BParam.new
      b_param.stub(:params).and_return({s: "things"})
      component_creator = ComponentCreator.new(b_param: b_param)
      component_creator.create_components_from_params.should be_nil
    end
    it "should call the necessary methods to create a component on each component" do 
      b_param = BParam.new 
      components = [{component_type: "something"}, {component_type: "something"}]
      b_param.stub(:params).and_return(components: components)
      component_creator = ComponentCreator.new(b_param: b_param)
      component_creator.should_receive(:set_manufacturer_key).at_least(2).times.and_return(true)
      component_creator.should_receive(:set_component_type).at_least(2).times.and_return(true)
      component_creator.should_receive(:create_component).at_least(2).times.and_return(true)
      component_creator.create_components_from_params
    end
  end

end
