require "rails_helper"

RSpec.describe Component, type: :model do
  describe "component_type" do
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

  describe "set_front_or_rear" do
    it "returns the name of the ctype other if it should" do
      bike = FactoryBot.create(:bike)
      FactoryBot.create(:component, bike: bike, front_or_rear: "both")
      expect(bike.reload.components.count).to eq(2)
    end
  end

  describe "manufacturer_name" do
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    it "returns the name of the manufacturer if it isn't other" do
      component = Component.new(manufacturer: manufacturer, manufacturer_other: "ooooop")
      allow(component).to receive(:manufacturer_other).and_return("oooop")
      expect(component.manufacturer_name).to eq manufacturer.name
    end
  end

  describe "set_is_stock" do
    let(:manufacturer) { FactoryBot.create(:manufacturer) }
    it "sets not stock if description changed" do
      component = FactoryBot.create(:component, is_stock: true)
      expect(component.is_stock).to be_truthy
      component.year = 1987
      expect(component.is_stock).to be_truthy
      component.manufacturer_id = manufacturer.id
      component.set_is_stock
      expect(component.is_stock).to be_truthy
      component.description = "A new description"
      component.set_is_stock
      expect(component.is_stock).to be_falsey
    end
    it "sets not stock if component_model changed" do
      component = FactoryBot.create(:component, is_stock: true)
      expect(component.is_stock).to be_truthy
      component.component_model = "New mode"
      component.set_is_stock
      expect(component.is_stock).to be_falsey
    end
    it "skips if setting_is_stock" do
      component = FactoryBot.create(:component, is_stock: true)
      expect(component.is_stock).to be_truthy
      component.setting_is_stock = true
      component.component_model = "New mode"
      component.set_is_stock
      expect(component.is_stock).to be_truthy
    end
  end
end
