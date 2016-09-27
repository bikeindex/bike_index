require 'spec_helper'

describe ComponentCreator do
  describe 'set_manufacturer_key' do
    context 'manufacturer in db' do
      it 'sets the manufacturer_id' do
        m = FactoryGirl.create(:manufacturer, name: 'SRAM')
        c = { manufacturer: 'sram' }
        component = ComponentCreator.new.set_manufacturer_key(c)
        expect(component[:manufacturer_id]).to eq(m.id)
        expect(component[:manufacturer]).not_to be_present
      end
    end
    context 'unknown manufacturer' do
      it 'adds other manufacturer name and set the set the foreign keys' do
        m = FactoryGirl.create(:manufacturer, name: 'Other')
        c = { manufacturer: 'Gobbledy Gooky' }
        component = ComponentCreator.new.set_manufacturer_key(c)
        expect(component[:manufacturer_id]).to eq(m.id)
        expect(component[:manufacturer]).not_to be_present
        expect(component[:manufacturer_other]).to eq('Gobbledy Gooky')
      end
    end
    context 'manufacturer_id a manufacturer name' do
      it 'sets manufacturer_id correctly' do
        m = FactoryGirl.create(:manufacturer, name: 'SRAM')
        c = { manufacturer_id: 'sram' }
        component = ComponentCreator.new.set_manufacturer_key(c)
        expect(component[:manufacturer_id]).to eq(m.id)
        expect(component[:manufacturer]).not_to be_present
      end
    end
  end

  describe 'set_component_type' do
    it 'sets the component_type from a string' do
      ctype = FactoryGirl.create(:ctype, name: 'Stuff blows')
      c = { component_type: 'sTuff Blows ' }
      component = ComponentCreator.new.set_component_type(c)
      expect(component[:ctype_id]).to eq(ctype.id)
      expect(component[:component_type]).not_to be_present
    end
    it "creates a new component type if we don't recognize it" do
      c = { component_type: 'Hubs' }
      component = ComponentCreator.new.set_component_type(c)
      expect(component[:ctype_id]).to eq(Ctype.unknown.id)
      expect(component[:ctype_other]).to eq('Hubs')
      expect(component[:component_type]).not_to be_present
    end
  end

  describe 'create_component' do
    it 'creates the component' do
      bike = FactoryGirl.create(:bike)
      manufacturer = FactoryGirl.create(:manufacturer, name: 'Somecool THING')
      component = { description: 'Stuff', mnfg_name: 'Somecool thing' }
      component_creator = ComponentCreator.new(bike: bike)
      component_creator.create_component(component)
      expect(bike.reload.components.count).to eq(1)
      expect(bike.components.last.manufacturer).to eq(manufacturer)
    end
    it "creates the component and ignore attributes it shouldn't use" do
      bike = FactoryGirl.create(:bike)
      component = { description: 'Stuff', cgroup: 'Drivetrain and brakes' }
      component_creator = ComponentCreator.new(bike: bike)
      component_creator.create_component(component)
      expect(bike.reload.components.count).to eq(1)
    end
  end

  describe 'create_components_from_params' do
    it 'returns nil if there are no components' do
      b_param = BParam.new
      allow(b_param).to receive(:params).and_return(s: 'things')
      component_creator = ComponentCreator.new(b_param: b_param)
      expect(component_creator.create_components_from_params).to be_nil
    end
    it 'calls the necessary methods to create a component on each component' do
      b_param = BParam.new
      components = [{ component_type: 'something' }, { component_type: 'something' }]
      allow(b_param).to receive(:params).and_return({ components: components }.as_json)
      component_creator = ComponentCreator.new(b_param: b_param)
      expect(component_creator).to receive(:set_manufacturer_key).at_least(2).times.and_return(true)
      expect(component_creator).to receive(:set_component_type).at_least(2).times.and_return(true)
      expect(component_creator).to receive(:create_component).at_least(2).times.and_return(true)
      component_creator.create_components_from_params
    end
  end
end
