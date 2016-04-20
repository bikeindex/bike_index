require 'spec_helper'

describe Component do
  describe 'validations' do
    it { is_expected.to belong_to :bike }
    it { is_expected.to belong_to :manufacturer }
    it { is_expected.to belong_to :ctype }
  end

  describe 'component_type' do
    it "returns the name of the ctype other if it should" do
      ctype = Ctype.new
      component = Component.new
      allow(component).to receive(:ctype).and_return(ctype)
      allow(ctype).to receive(:name).and_return("Other")
      allow(component).to receive(:ctype_other).and_return("OOOP")
      expect(component.component_type).to eq("OOOP")
    end

    it "returns the name of the ctype" do
      ctype = Ctype.new
      component = Component.new
      allow(component).to receive(:ctype).and_return(ctype)
      allow(ctype).to receive(:name).and_return("stuff")
      expect(component.component_type).to eq("stuff")
    end
  end

  describe 'set_front_or_rear' do
    it "returns the name of the ctype other if it should" do
      bike = FactoryGirl.create(:bike)
      component = FactoryGirl.create(:component, bike: bike,  front_or_rear: "both")
      expect(bike.reload.components.count).to eq(2)
    end
  end

  describe 'manufacturer_name' do
    it "returns the value of manufacturer_other if manufacturer is other" do
      mnfg = Ctype.new
      component = Component.new
      allow(component).to receive(:manufacturer).and_return(mnfg)
      allow(mnfg).to receive(:name).and_return("stuff")
      expect(component.manufacturer_name).to eq("stuff")
    end

    it "returns the name of the manufacturer if it isn't other" do
      mnfg = Ctype.new
      component = Component.new
      allow(component).to receive(:manufacturer).and_return(mnfg)
      allow(component).to receive(:manufacturer_other).and_return("oooop")
      allow(mnfg).to receive(:name).and_return("Other")
      expect(component.manufacturer_name).to eq("oooop")
    end
  end

  describe 'set_is_stock' do
    it "sets not stock if description changed" do
      component = FactoryGirl.create(:component, is_stock: true)
      expect(component.is_stock).to be_truthy
      component.year = 1987
      expect(component.is_stock).to be_truthy
      component.manufacturer_id = 69
      component.set_is_stock
      expect(component.is_stock).to be_truthy
      component.description = "A new description"
      component.set_is_stock
      expect(component.is_stock).to be_falsey
    end
    it "sets not stock if model_name changed" do
      component = FactoryGirl.create(:component, is_stock: true)
      expect(component.is_stock).to be_truthy
      component.model_name = "New mode"
      component.set_is_stock
      expect(component.is_stock).to be_falsey
    end
    it "skips if setting_is_stock" do
      component = FactoryGirl.create(:component, is_stock: true)
      expect(component.is_stock).to be_truthy
      component.setting_is_stock = true
      component.model_name = "New mode"
      component.set_is_stock
      expect(component.is_stock).to be_truthy
    end
    it "has before_save_callback_method defined for clean_frame_size" do
      expect(Component._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:raw_filter).include?(:set_is_stock)).to eq(true)
    end
  end

  # describe 'fuzzy_assign_mnfg' do
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
