require "spec_helper"

describe ComponentCreator do
  describe "set_manufacturer_key" do
    context "manufacturer in db" do
      let(:manufacturer) { FactoryBot.create(:manufacturer, name: "SRAM") }
      let(:target) { { manufacturer_id: manufacturer.id } }
      it "sets the manufacturer_id" do
        expect(ComponentCreator.new.manufacturer_hash(manufacturer: manufacturer.slug)).to eq target
        expect(ComponentCreator.new.manufacturer_hash(manufacturer_id: "#{manufacturer.name} ")).to eq target
      end
    end
    context "unknown manufacturer" do
      let(:target) { { manufacturer_id: Manufacturer.other.id, manufacturer_other: "Gobbledy Gooky" } }
      it "adds other manufacturer name and set the set the foreign keys" do
        expect(ComponentCreator.new.manufacturer_hash(manufacturer: "Gobbledy Gooky")).to eq target
        # If it's already existing, it should stay the same
        expect(ComponentCreator.new.manufacturer_hash(target)).to eq target
      end
    end
    context "no manufacturer" do
      it "returns empty" do
        expect(ComponentCreator.new.manufacturer_hash(model_name: "FFFF")).to eq({})
      end
    end
  end

  describe "set_component_type" do
    it "sets the component_type from a string" do
      ctype = FactoryBot.create(:ctype, name: "Stuff blows")
      c = { component_type: "sTuff Blows " }
      expect(ComponentCreator.new.component_type_hash(c)).to eq(ctype_id: ctype.id)
    end
    context "unknown component type" do
      let(:target) { { ctype_id: Ctype.other.id, ctype_other: "Spiked Hubs" } }
      it "creates a new component type if we don't recognize it" do
        expect(ComponentCreator.new.component_type_hash(component_type: "Spiked Hubs")).to eq target
      end
    end
    context "already has ctype_id" do
      target = { ctype_id: Ctype.other.id, ctype_other: "Some other component" }
      it "creates a new component type if we don't recognize it" do
        expect(ComponentCreator.new.component_type_hash(target)).to eq target
      end
    end
  end

  describe "create_component" do
    it "creates the component" do
      bike = FactoryBot.create(:bike)
      manufacturer = FactoryBot.create(:manufacturer, name: "Somecool THING")
      component = { description: "Stuff", mnfg_name: "Somecool thing" }
      component_creator = ComponentCreator.new(bike: bike)
      component_creator.create_component(component)
      expect(bike.reload.components.count).to eq(1)
      expect(bike.components.last.manufacturer).to eq(manufacturer)
    end
    it "creates the component and ignore attributes it shouldn't use" do
      bike = FactoryBot.create(:bike)
      component = { description: "Stuff", cgroup: "Drivetrain and brakes" }
      component_creator = ComponentCreator.new(bike: bike)
      component_creator.create_component(component)
      expect(bike.reload.components.count).to eq(1)
    end
  end

  describe "create_components_from_params" do
    it "returns nil if there are no components" do
      b_param = BParam.new
      allow(b_param).to receive(:params).and_return(s: "things")
      component_creator = ComponentCreator.new(b_param: b_param)
      expect(component_creator.create_components_from_params).to be_nil
    end
    it "calls the necessary methods to create a component on each component" do
      b_param = BParam.new
      components = [{ component_type: "something" }, { component_type: "something" }]
      allow(b_param).to receive(:params).and_return({ components: components }.as_json)
      component_creator = ComponentCreator.new(b_param: b_param)
      expect(component_creator).to receive(:set_manufacturer_key).at_least(2).times.and_return(true)
      expect(component_creator).to receive(:set_component_type).at_least(2).times.and_return(true)
      expect(component_creator).to receive(:create_component).at_least(2).times.and_return(true)
      component_creator.create_components_from_params
    end
  end
end
