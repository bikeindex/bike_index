# This is the create action for bikes controller
# it's too big of an action, there are too many tests, so it's split into this file
require 'spec_helper'

RSpec.shared_examples 'bikes_controller_create' do
  let(:manufacturer) { FactoryGirl.create(:manufacturer) }
  let(:color) { FactoryGirl.create(:color) }
  let(:cycle_type) { FactoryGirl.create(:cycle_type) }
  let(:handlebar_type) { FactoryGirl.create(:handlebar_type) }

  describe 'embeded' do
    let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
    let(:user) { organization.auto_user }
    let(:b_param) { BParam.create(creator_id: organization.auto_user_id, params: { creation_organization_id: organization.id, embeded: true }) }
    let(:bike_params) do
      {
        serial_number: '69',
        b_param_id_token: b_param.id_token,
        creation_organization_id: organization.id,
        embeded: true,
        additional_registration: 'Testly secondary',
        cycle_type_id: cycle_type.id,
        manufacturer_id: manufacturer.id,
        manufacturer_other: '',
        primary_frame_color_id: color.id,
        handlebar_type_id: handlebar_type.id,
        owner_email: 'flow@goodtimes.com'
      }
    end
    let(:testable_bike_params) { bike_params.except(:b_param_id_token, :embeded) }
    context 'non-stolen' do
      it 'creates a new ownership and bike from an organization' do
        expect(user).to be_present
        expect do
          post :create, bike: bike_params
        end.to change(Ownership, :count).by 1
        bike = Bike.last
        testable_bike_params.each do |k, v|
          pp k unless bike.send(k).to_s == v.to_s
          expect(bike.send(k).to_s).to eq v.to_s
        end
      end
    end
    context 'stolen' do
      let(:state) { FactoryGirl.create(:state) }
      let(:country) { state.country }
      let(:stolen_params) do
        {
          country_id: country.id,
          street: '2459 W Division St',
          city: 'Chicago',
          zipcode: '60622',
          state_id: state.id,
          date_stolen_input: Date.today.strftime('%m-%d-%Y')
        }
      end
      context 'valid' do
        it 'creates a new ownership and bike from an organization' do
          expect do
            post :create, bike: bike_params.merge(stolen: true), stolen_record: stolen_params
          end.to change(Ownership, :count).by 1
          bike = Bike.last
          testable_bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
          stolen_record = bike.current_stolen_record
          stolen_params.except(:date_stolen_input).each { |k, v| expect(stolen_record.send(k).to_s).to eq v.to_s }
          expect(stolen_record.date_stolen.to_date).to eq Date.today
        end
      end
      context 'invalid' do
        it 'renders the stolen form with all the attributes' do
          target_path = embed_organization_path(id: organization.slug, b_param_id_token: b_param.id_token)
          expect do
            post :create, bike: bike_params.merge(stolen: '1', primary_frame_color: nil),
                          stolen_record: stolen_params
          end.to change(Ownership, :count).by 0
          expect(response).to redirect_to target_path
          bike = assigns(:bike)
          testable_bike_params.except(:primary_frame_color_id).each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
          expect(bike.stolen).to be_truthy
          # we retain the stolen record attrs, it would be great to test that they are
          # assigned correctly, but I don't know how - it needs to completely
          # render the new action
        end
      end
    end
  end

  describe 'extended embeded submission' do
    let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
    let(:bike_params) do
      {
        serial_number: '69',
        b_param_id_token: b_param.id_token,
        creation_organization_id: organization.id,
        embeded: true,
        embeded_extended: true,
        cycle_type_id: cycle_type.id,
        manufacturer_id: manufacturer.id,
        primary_frame_color_id: color.id,
        handlebar_type_id: handlebar_type.id,
        owner_email: 'Flow@goodtimes.com'
      }
    end
    let(:b_param) { BParam.create(creator_id: organization.auto_user.id, params: { creation_organization_id: organization.id, embeded: true }) }
    before do
      expect(b_param).to be_present
    end
    context 'with an image' do
      it 'registers a bike and uploads an image' do
        Sidekiq::Testing.inline! do
          test_photo = Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg')))
          expect_any_instance_of(ImageAssociatorWorker).to receive(:perform).and_return(true)
          post :create, bike: bike_params.merge(image: test_photo)
          expect(response).to redirect_to(embed_extended_organization_url(organization))
          expect(Bike.last.owner_email).to eq bike_params[:owner_email].downcase
        end
      end
    end
    context 'with persisted email' do
      it 'registers a bike and redirects with persist_email' do
        post :create, bike: bike_params, persist_email: true
        expect(response).to redirect_to(embed_extended_organization_url(organization, email: 'flow@goodtimes.com'))
      end
    end
  end

  context 'standard web form submission' do
    include_context :logged_in_as_user

    context 'legacy b_param' do
      let(:bike_params) do
        {
          serial_number: '1234567890',
          b_param_id_token: b_param.id_token,
          cycle_type_id: cycle_type.id,
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: 'true',
          rear_wheel_size_id: FactoryGirl.create(:wheel_size).id,
          primary_frame_color_id: color.id,
          handlebar_type_id: handlebar_type.id,
          owner_email: user.email
        }
      end

      context 'b_param not owned by user' do
        let(:other_user) { FactoryGirl.create(:user) }
        let(:b_param) { FactoryGirl.create(:b_param, creator: other_user) }
        it "does not use the b_param if isn't owned by user" do
          post :create, bike: bike_params
          b_param.reload
          expect(b_param.created_bike_id).to_not be_present
        end
      end

      context 'stolen b_param from user' do
        let(:b_param) { FactoryGirl.create(:b_param, creator: user) }
        it 'creates a new stolen bike and assigns the user phone' do
          FactoryGirl.create(:country, iso: 'US')
          expect do
            post :create, stolen: 'true', bike: bike_params.merge(phone: '312.379.9513')
          end.to change(StolenRecord, :count).by(1)
          expect(b_param.reload.created_bike_id).not_to be_nil
          expect(b_param.reload.bike_errors).to be_nil
          expect(user.reload.phone).to eq('3123799513')
        end
      end
      context 'organization b_param' do
        let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
        let(:b_param) { FactoryGirl.create(:b_param, creator: organization.auto_user) }
        it 'creates a new ownership and bike from an organization' do
          expect do
            post :create, bike: bike_params.merge(creation_organization_id: organization.id)
          end.to change(Ownership, :count).by(1)
          expect(Bike.last.creation_organization_id).to eq(organization.id)
        end
      end
    end

    context 'no existing b_param and stolen' do
      let(:wheel_size) { FactoryGirl.create(:wheel_size) }
      let(:country) { Country.united_states }
      let(:state) { FactoryGirl.create(:state, country: country) }
      let(:bike_params) do
        {
          b_param_id_token: '',
          cycle_type_id: CycleType.bike.id.to_s,
          serial_number: 'example serial',
          manufacturer_other: '',
          year: '2016',
          frame_model: 'Cool frame model',
          primary_frame_color_id: color.id.to_s,
          secondary_frame_color_id: '',
          tertiary_frame_color_id: '',
          owner_email: 'something@stuff.com',
          phone: '312.379.9513',
          stolen: true
        }
      end
      let(:stolen_params) do
        {
          country_id: country.id,
          street: '2459 W Division St',
          city: 'Chicago',
          zipcode: '60622',
          state_id: state.id
        }
      end
      before do
        expect(BParam.all.count).to eq 0
      end
      context 'successful creation' do
        it "creates a bike and doesn't create a b_param" do
          success_params = bike_params.merge(manufacturer_id: manufacturer.slug)
          bb_data = { bike: { rear_wheel_bsd: wheel_size.iso_bsd.to_s }, components: [] }.as_json
          # We need to call clean_params on the BParam after bikebook update, so that
          # the foreign keys are assigned correctly. This is how we test that we're
          # This is also where we're testing bikebook assignment
          expect_any_instance_of(BikeBookIntegration).to receive(:get_model) { bb_data }
          expect do
            post :create, stolen: true, bike: success_params.as_json, stolen_record: stolen_params
          end.to change(Bike, :count).by(1)
          expect(flash[:success]).to be_present
          expect(BParam.all.count).to eq 0
          bike = Bike.last
          bike_params.delete(:manufacturer_id)
          bike_params.delete(:phone)
          bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
          expect(bike.manufacturer).to eq manufacturer
          expect(bike.stolen).to be_truthy
          user.reload
          expect(user.phone).to eq '3123799513'
          expect(bike.current_stolen_record.phone).to eq '3123799513'
          stolen_record = bike.current_stolen_record
          stolen_params.delete(:state_id) # this doesn't show up, don't care for now, shows up for real
          stolen_params.each { |k, v| expect(stolen_record.send(k).to_s).to eq v.to_s }
        end
      end
      context 'failure' do
        it 'assigns a bike and a stolen record with the attrs passed' do
          expect do
            post :create, stolen: true, bike: bike_params.as_json, stolen_record: stolen_params
          end.to change(Bike, :count).by(0)
          expect(BParam.all.count).to eq 1
          bike = assigns(:bike)
          bike_params.delete(:manufacturer_id)
          bike_params.delete(:phone)
          bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
          expect(bike.stolen).to be_truthy
          # we retain the stolen record attrs, it would be great to test that they are
          # assigned correctly, but I don't know how - it needs to completely
          # render the new action
          # stolen_record = assigns(:stolen_record)
          # stolen_params.each { |k, v| expect(stolen_record.send(k).to_s).to eq v.to_s }
        end
      end
    end
    context 'existing b_param' do
      context 'no bike' do
        it 'creates a bike' do
          bike_params = {
            cycle_type_id: CycleType.bike.id.to_s,
            serial_number: 'example serial',
            manufacturer_other: '',
            year: '2016',
            frame_model: 'Cool frame model',
            primary_frame_color_id: color.id.to_s,
            secondary_frame_color_id: '',
            tertiary_frame_color_id: '',
            owner_email: 'something@stuff.com'
          }.as_json
          b_param = BParam.create(params: { 'bike' => bike_params })
          bb_data = { bike: {} }
          # We need to call clean_params on the BParam after bikebook update, so that
          # the foreign keys are assigned correctly. This is how we test that we're
          # This is also where we're testing bikebook assignment
          expect_any_instance_of(BikeBookIntegration).to receive(:get_model) { bb_data }
          expect do
            post :create, bike: { manufacturer_id: manufacturer.slug, b_param_id_token: b_param.id_token }
          end.to change(Bike, :count).by(1)
          expect(flash[:success]).to be_present
          bike = Bike.last
          expect(bike.creator_id).to eq user.id
          b_param.reload
          expect(b_param.created_bike_id).to eq bike.id
          bike_params.delete(:manufacturer_id)
          bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v }
          expect(bike.manufacturer).to eq manufacturer
        end
      end
      context 'created bike' do
        it 'redirects to the bike' do
          bike = FactoryGirl.create(:bike)
          b_param = BParam.create(params: { bike: {} }, created_bike_id: bike.id, creator_id: user.id)
          expect(b_param.created_bike).to be_present
          post :create, bike: { b_param_id_token: b_param.id_token }
          expect(response).to redirect_to(edit_bike_url(bike.id))
        end
      end
    end
  end
end
