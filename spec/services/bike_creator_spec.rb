require 'spec_helper'

describe BikeCreator do
  describe 'include_bike_book' do
    it "returns the bike if stuff isn't present" do
      creator = BikeCreator.new
      expect(creator.add_bike_book_data).to be_nil
    end
    it 'adds se bike data if it exists' do
      manufacturer = FactoryBot.create(:manufacturer, name: 'SE Bikes')
      color = FactoryBot.create(:color)
      bike = {
        serial_number: 'Some serial',
        description: 'Input description',
        manufacturer_id: manufacturer.id,
        year: 2014,
        frame_model: 'Draft',
        primary_frame_color_id: color.id
      }
      b_param = FactoryBot.create(:b_param, params: { bike: bike })
      BikeCreator.new(b_param).add_bike_book_data

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
      bike = FactoryBot.create(:bike)
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
      bike = FactoryBot.create(:bike)
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
    describe 'no_duplicate' do
      let(:existing_bike) { FactoryBot.create(:bike, serial_number: 'some serial number', owner_email: email) }
      let(:new_bike) { FactoryBot.create(:bike, serial_number: 'some serial number', owner_email: new_email) }
      let!(:ownerships) do
        FactoryBot.create(:ownership, bike: existing_bike, owner_email: email)
        FactoryBot.create(:ownership, bike: new_bike, owner_email: new_email)
      end
      let(:params) do
        {
          bike: {
            serial_number: 'some serial number',
            owner_email: new_email,
            no_duplicate: true
          }
        }
      end
      let(:b_param) { FactoryBot.create(:b_param, creator: existing_bike.current_ownership.creator, params: params) }
      context 'same email' do
        let(:email) { 'something@gmail.com' }
        let(:new_email) { 'Something@GMAIL.com' }
        it 'finds a duplicate' do
          expect(b_param.no_duplicate).to be_truthy
          expect(b_param.find_duplicate_bike(new_bike)).to be_truthy
          expect do
            BikeCreator.new(b_param).validate_record(new_bike)
          end.to change(Ownership, :count).by -1
          b_param.reload
          expect(b_param.created_bike_id).to eq existing_bike.id
          expect(Bike.where(id: new_bike.id)).to_not be_present
        end
      end
      context 'different email' do
        let(:email) { 'something@gmail.com' }
        let(:new_email) { 'newsomething@gmail.com' }
        it 'does not find a non-duplicate' do
          expect(b_param.no_duplicate).to be_truthy
          expect(b_param.find_duplicate_bike(new_bike)).to be_falsey
          expect do
            BikeCreator.new(b_param).validate_record(new_bike)
          end.to change(Ownership, :count).by 0
          b_param.reload
          expect(b_param.created_bike_id).to eq new_bike.id
        end
      end
    end
  end

  describe 'save_bike' do
    Sidekiq::Testing.inline! do
      it 'creates a bike with the parameters it is passed and returns it' do
        propulsion_type = FactoryBot.create(:propulsion_type)
        cycle_type = FactoryBot.create(:cycle_type)
        organization = FactoryBot.create(:organization)
        user = FactoryBot.create(:user)
        manufacturer = FactoryBot.create(:manufacturer)
        color = FactoryBot.create(:color)
        wheel_size = FactoryBot.create(:wheel_size)
        b_param = BParam.new(origin: 'api_v1')
        creator = BikeCreator.new(b_param)
        bike = Bike.new
        # allow(bike).to receive(:id).and_return(69)
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
          'handlebar_type' => 'bmx',
          'creator' => user
        )
        expect do
          saved_bike = creator.save_bike(new_bike)
        end.to change(Bike, :count).by(1)
      end
    end

    it 'enque listing order working' do
      Sidekiq::Worker.clear_all
      Sidekiq::Testing.fake! do
        b_param = BParam.new
        creator = BikeCreator.new(b_param)
        bike = FactoryBot.create(:bike)
        expect(creator).to receive(:create_associations).and_return(bike)
        expect(creator).to receive(:validate_record).and_return(bike)
        expect do
          creator.save_bike(bike)
        end.to change(AfterBikeSaveWorker.jobs, :size).by(1)
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
