require 'spec_helper'

describe BikeCreator do
  describe 'include_bike_book' do
    it "returns the bike if stuff isn't present" do
      creator = BikeCreator.new
      expect(creator.add_bike_book_data).to be_nil
    end
    it 'adds se bike data if it exists' do
      manufacturer = FactoryGirl.create(:manufacturer, name: 'SE Bikes')
      color = FactoryGirl.create(:color)
      bike = {
        serial_number: 'Some serial',
        description: 'Input description',
        manufacturer_id: manufacturer.id,
        year: 2014,
        frame_model: 'Draft',
        primary_frame_color_id: color.id
      }
      b_param = FactoryGirl.create(:b_param, params: { bike: bike })
      creator = BikeCreator.new(b_param).add_bike_book_data

      b_param.reload
      # pp b_param.params
      expect(b_param.params['components'].count).to be > 5
      expect(b_param.params['components'].count { |c| c['is_stock'] }).to be > 5
      expect(b_param.params['components'].count { |c| !c['is_stock'] }).to eq(0)
      expect(b_param.bike['description']).not_to eq('Input description')
      expect(b_param.bike['serial_number']).to eq('Some serial')
      expect(b_param.bike['primary_frame_color_id']).to eq(color.id)
    end
  end

  describe 'build_new_bike' do
    it 'calls creator_builder' do
      b_param = BParam.new
      expect_any_instance_of(BikeCreatorBuilder).to receive(:build_new).and_return(true)
      BikeCreator.new(b_param).build_new_bike
    end
  end

  describe 'build_bike' do
    it 'calls creator_builder' do
      b_param = BParam.new
      expect_any_instance_of(BikeCreatorBuilder).to receive(:build).and_return(Bike.new)
      expect(BikeCreator.new(b_param).build_bike).to be_truthy
    end
  end

  describe 'create_associations' do
    it 'calls creator_associator' do
      b_param = BParam.new
      bike = Bike.new
      allow(b_param).to receive(:bike).and_return(bike)
      expect_any_instance_of(BikeCreatorAssociator).to receive(:associate).and_return(bike)
      BikeCreator.new(b_param).create_associations(bike)
    end
  end

  describe 'clear_bike' do
    it 'removes the existing bike and transfer the errors to a new active record object' do
      b_param = BParam.new
      bike = FactoryGirl.create(:bike)
      bike.errors.add(:rando_error, 'LOLZ')
      expect_any_instance_of(BikeCreatorBuilder).to receive(:build).and_return(Bike.new)
      creator = BikeCreator.new(b_param).clear_bike(bike)
      expect(creator.errors.messages[:rando_error]).not_to be_nil
      expect(Bike.where(id: bike.id)).to be_empty
    end
  end

  describe 'validate_record' do
    it 'calls remove associations if the bike was created and there are errors' do
      b_param = BParam.new
      bike = Bike.new
      allow(b_param).to receive(:bike).and_return(bike)
      allow(bike).to receive(:errors).and_return(messages: 'some errors')
      creator = BikeCreator.new(b_param)
      expect(creator).to receive(:clear_bike).and_return(bike)
      creator.validate_record(bike)
    end

    it 'calls delete the already existing bike if one exists' do
      # This is to clean up duplicates, people press the 'add bike button' many times when its slow to respond
      b_param = BParam.new
      bike = FactoryGirl.create(:bike)
      bike1 = Bike.new
      allow(b_param).to receive(:created_bike).and_return(bike1)
      expect(BikeCreator.new(b_param).validate_record(bike)).to eq(bike1)
      expect(Bike.where(id: bike1.id)).to be_empty
    end

    it 'associates the b_param with the bike and clear the bike_errors if the bike is created' do
      b_param = BParam.new
      bike = Bike.new
      allow(b_param).to receive(:id).and_return(42)
      allow(bike).to receive(:id).and_return(69)
      allow(bike).to receive(:errors).and_return(nil)
      # b_param.should_receive(:update_attributes).with(created_bike_id: 69)
      expect(b_param).to receive(:update_attributes).with(created_bike_id: 69, bike_errors: nil)
      BikeCreator.new(b_param).validate_record(bike)
    end
  end

  describe 'save_bike' do
    Sidekiq::Testing.inline! do
      it 'creates a bike with the parameters it is passed and return it' do
        propulsion_type = FactoryGirl.create(:propulsion_type)
        cycle_type = FactoryGirl.create(:cycle_type)
        organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:user)
        manufacturer = FactoryGirl.create(:manufacturer)
        color = FactoryGirl.create(:color)
        handlebar_type = FactoryGirl.create(:handlebar_type)
        wheel_size = FactoryGirl.create(:wheel_size)
        b_param = BParam.new
        creator = BikeCreator.new(b_param)
        bike = Bike.new
        allow(bike).to receive(:id).and_return(69)
        expect(creator).to receive(:create_associations).and_return(bike)
        expect(creator).to receive(:validate_record).and_return(bike)
        new_bike = Bike.new(
          creation_organization_id: organization.id,
          propulsion_type_id: propulsion_type.id,
          'cycle_type_id' => cycle_type.id,
          'serial_number' => 'BIKE TOKENd',
          'manufacturer_id' => manufacturer.id,
          'rear_tire_narrow' => 'true',
          'rear_wheel_size_id' => wheel_size.id,
          'primary_frame_color_id' => color.id,
          'handlebar_type_id' => handlebar_type,
          'creator' => user
        )
        expect do
          creator.save_bike(new_bike)
        end.to change(Bike, :count).by(1)
      end
    end

    it 'enque listing order working' do
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.fake! do
        b_param = BParam.new
        creator = BikeCreator.new(b_param)
        bike = FactoryGirl.create(:bike)
        expect(creator).to receive(:create_associations).and_return(bike)
        expect(creator).to receive(:validate_record).and_return(bike)
        expect do
          creator.save_bike(bike)
        end.to change(ListingOrderWorker.jobs, :size).by(2)
      end
    end
  end

  describe 'new_bike' do
    it 'calls the required methods' do
      creator = BikeCreator.new
      expect(creator).to receive(:build_new_bike).and_return(true)
      creator.new_bike
    end
  end

  describe 'create_bike' do
    Sidekiq::Testing.inline! do
      it 'saves the bike' do
        b_param = BParam.new
        bike = Bike.new
        creator = BikeCreator.new(b_param)
        expect(creator).to receive(:add_bike_book_data).at_least(1).times.and_return(nil)
        expect(creator).to receive(:build_bike).at_least(1).times.and_return(bike)
        # ListingOrderWorker.any_instance.should_receive(:perform).and_return(true)
        expect(bike).to receive(:save).and_return(true)
        creator.create_bike
      end
    end

    it 'returns the bike instead of saving if the bike has errors' do
      b_param = BParam.new
      bike = Bike.new(serial_number: 'LOLZ')
      bike.errors.add(:errory, 'something')
      creator = BikeCreator.new(b_param)
      expect(creator).to receive(:build_bike).and_return(bike)
      response = creator.create_bike
      expect(response.errors[:errory]).to eq(['something'])
    end
  end
end
