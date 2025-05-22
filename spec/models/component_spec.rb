require "rails_helper"

RSpec.describe Component, type: :model do
  describe "component_type" do
    let(:component) { FactoryBot.create(:component, ctype:, ctype_other:) }
    let(:ctype) { FactoryBot.create(:ctype) }
    let(:ctype_other) { "" }

    it "returns the name of the ctype other if it should" do
      expect(component.reload.component_type).to eq ctype.name
      expect(component.ctype_other).to be_nil
    end

    context "with ctype other" do
      let(:ctype) { Ctype.other }
      let(:ctype_other) { " OthER\n"}
      it "returns other" do
        expect(component.reload.component_type).to eq "unknown"
        expect(component.ctype_other).to be_nil
      end

      context "with ctype_other set" do
        let(:ctype_other) { "cool thing we don't have " }
        it "returns the name" do
          expect(component.reload.component_type).to eq ctype_other.strip
          expect(component.ctype_other).to eq ctype_other.strip
        end
      end
    end
  end

  describe "set_front_or_rear" do
    it "returns the name of the ctype other if it should" do
      bike = FactoryBot.create(:bike)
      FactoryBot.create(:component, bike: bike, front_or_rear: "both")
      expect(bike.reload.components.count).to eq(2)
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
