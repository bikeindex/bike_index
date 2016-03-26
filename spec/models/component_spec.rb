require 'spec_helper'

describe Component do

  describe :validations do
    it { should belong_to :bike }
    it { should belong_to :manufacturer }
    it { should belong_to :ctype }
  end

  describe :component_type do 
    it "returns the name of the ctype other if it should" do 
      ctype = Ctype.new
      component = Component.new
      component.stub(:ctype).and_return(ctype)
      ctype.stub(:name).and_return("Other")
      component.stub(:ctype_other).and_return("OOOP")
      component.component_type.should eq("OOOP")
    end

    it "returns the name of the ctype" do 
      ctype = Ctype.new
      component = Component.new
      component.stub(:ctype).and_return(ctype)
      ctype.stub(:name).and_return("stuff")
      component.component_type.should eq("stuff")
    end
  end

  describe :set_front_or_rear do 
    it "returns the name of the ctype other if it should" do 
      bike = FactoryGirl.create(:bike)
      component = FactoryGirl.create(:component, bike: bike,  front_or_rear: "both")
      bike.reload.components.count.should eq(2)
    end
  end

  describe :manufacturer_name do 
    it "returns the value of manufacturer_other if manufacturer is other" do 
      mnfg = Ctype.new
      component = Component.new
      component.stub(:manufacturer).and_return(mnfg)
      mnfg.stub(:name).and_return("stuff")
      component.manufacturer_name.should eq("stuff")
    end

    it "returns the name of the manufacturer if it isn't other" do
      mnfg = Ctype.new
      component = Component.new
      component.stub(:manufacturer).and_return(mnfg)
      component.stub(:manufacturer_other).and_return("oooop")
      mnfg.stub(:name).and_return("Other")
      component.manufacturer_name.should eq("oooop")
    end
  end

  describe :set_is_stock do 
    it "sets not stock if description changed" do 
      component = FactoryGirl.create(:component, is_stock: true)
      component.is_stock.should be_true
      component.year = 1987
      component.is_stock.should be_true
      component.manufacturer_id = 69
      component.set_is_stock
      component.is_stock.should be_true
      component.description = "A new description"
      component.set_is_stock
      component.is_stock.should be_false
    end
    it "sets not stock if model_name changed" do 
      component = FactoryGirl.create(:component, is_stock: true)
      component.is_stock.should be_true
      component.model_name = "New mode"
      component.set_is_stock
      component.is_stock.should be_false
    end
    it "skips if setting_is_stock" do 
      component = FactoryGirl.create(:component, is_stock: true)
      component.is_stock.should be_true
      component.setting_is_stock = true
      component.model_name = "New mode"
      component.set_is_stock
      component.is_stock.should be_true
    end
    it "has before_save_callback_method defined for clean_frame_size" do
      Component._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_is_stock).should == true
    end
  end

  # describe :fuzzy_assign_mnfg do
  #   context 'manufacturer_id a manufacturer name' do
  #     it 'sets manufacturer_id correctly' do
  #       m = FactoryGirl.create(:manufacturer, name: 'SRAM')
  #       c = { manufacturer_id: 'sram' }
  #       component = ComponentCreator.new().set_manufacturer_key(c)
  #       component[:manufacturer_id].should eq(m.id)
  #       component[:manufacturer].should_not be_present
  #     end
  #   end
  # end

end
