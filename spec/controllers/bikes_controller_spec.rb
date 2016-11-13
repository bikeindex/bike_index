require 'spec_helper'

describe BikesController do
  describe 'index' do
    include_context :geocoder_default_location
    let(:stolen_bike) { FactoryGirl.create(:stolen_bike, latitude: default_location[:latitude], longitude: default_location[:longitude]) }
    let(:serial) { '1234567890' }
    let(:stolen_bike_2) { FactoryGirl.create(:stolen_bike, latitude: 41.8961603, longitude: -87.677215) }
    let(:non_stolen_bike) { FactoryGirl.create(:bike, serial_number: '1234567890') }
    let(:ip_address) { '127.0.0.1' }
    let(:target_interpreted_params) { Bike.searchable_interpreted_params(query_params, ip: ip_address) }
    context 'with subdomain' do
      it 'redirects to no subdomain' do
        @request.host = 'stolen.example.com'
        get :index
        expect(response).to redirect_to bikes_url(subdomain: false)
      end
    end
    describe 'assignment' do
      before do
        expect([non_stolen_bike, stolen_bike, stolen_bike_2].size).to eq 3
      end
      context 'no params' do
        it 'assigns defaults, stolenness: stolen' do
          get :index
          expect(response.status).to eq 200
          expect(response).to render_template(:index)
          expect(response).to render_with_layout('application_revised')
          expect(flash).to_not be_present
          expect(assigns(:interpreted_params)).to eq(stolenness: 'stolen')
          expect(assigns(:selected_query_items_options)).to eq([])
          expect(assigns(:bikes).map(&:id)).to eq([stolen_bike.id, stolen_bike_2.id])
          expect(assigns(:page_id)).to eq 'bikes_index'
        end
      end
      context 'query_items and serial search' do
        let(:manufacturer) { non_stolen_bike.manufacturer }
        let(:color) { non_stolen_bike.primary_frame_color }
        let(:query_params) { { serial: "#{serial}0d", query_items: [color.search_id, manufacturer.search_id], stolenness: 'non' } }
        let(:target_selected_query_items_options) { Bike.selected_query_items_options(target_interpreted_params) }
        it 'assigns passed parameters, assigns close_serials' do
          get :index, query_params
          expect(response.status).to eq 200
          expect(assigns(:interpreted_params)).to eq target_interpreted_params
          expect(assigns(:selected_query_items_options)).to eq target_selected_query_items_options
          expect(assigns(:bikes).map(&:id)).to eq([])
          expect(assigns(:close_serials).map(&:id)).to eq([non_stolen_bike.id])
        end
      end
      context 'ip proximity' do
        let(:query_params) { { location: 'you', distance: 1, stolenness: 'proximity' } }
        context 'found location' do
          it 'assigns passed parameters and close_serials' do
            expect_any_instance_of(BikesController).to receive(:forwarded_ip_address) { ip_address }
            allow(Geocoder).to receive(:search) { production_ip_search_result }
            get :index, query_params
            expect(response.status).to eq 200
            expect(assigns(:interpreted_params)).to eq target_interpreted_params
            expect(assigns(:bikes).map(&:id)).to eq([stolen_bike.id])
          end
        end
        context 'unknown location' do
          let(:bounding_box) { [66.00, -84.22, 67.000, (0.0 / 0)] } # Override bounding box stub in geocoder_default_location
          it 'includes a flash[:info] for unknown location, renders non-proximity' do
            get :index, query_params
            expect(response.status).to eq 200
            expect(flash[:info]).to match(/location/)
            expect(query_params[:stolenness]).to eq 'proximity'
            expect(assigns(:interpreted_params)[:stolenness]).to eq 'stolen'
          end
        end
      end
      context 'passed all permitted params' do
        let(:query_params) do
          {
            query: '1',
            manufacturer: '2',
            colors: %w(3 4),
            location: '5',
            distance: '6',
            serial: '9',
            query_items: %w(7 8),
            stolenness: 'all'
          }.as_json
        end
        it 'sends all the params we want to searchable_interpreted_params' do
          expect_any_instance_of(BikesController).to receive(:forwarded_ip_address) { 'special' }
          expect(Bike).to receive(:searchable_interpreted_params).with(query_params, ip: 'special') { {} }
          get :index, query_params
          expect(response.status).to eq 200
        end
      end
    end
  end

  describe 'show' do
    let(:ownership) { FactoryGirl.create(:ownership) }
    let(:user) { ownership.creator }
    let(:bike) { ownership.bike }
    context 'legacy' do
      context 'showing' do
        it 'shows the bike' do
          get :show, id: bike.id
          expect(response.status).to eq(200)
          expect(response).to render_template(:show)
          expect(response).to render_with_layout('application_revised')
          expect(assigns(:bike)).to be_decorated
          expect(flash).to_not be_present
        end
      end
      context 'example bike' do
        it 'shows the bike' do
          ownership.bike.update_attributes(example: true)
          get :show, id: bike.id
          expect(response).to render_template(:show)
          expect(response).to render_with_layout('application_revised')
          expect(assigns(:bike)).to be_decorated
        end
      end
      context 'hidden bikes' do
        context 'admin hidden (fake delete)' do
          it 'redirects and sets the flash' do
            ownership.bike.update_attributes(hidden: true)
            get :show, id: bike.id
            expect(response).to redirect_to(:root)
            expect(flash[:error]).to be_present
          end
        end
        context 'user hidden bike' do
          before do
            ownership.bike.update_attributes(marked_user_hidden: 'true')
          end
          context 'owner of bike viewing' do
            it 'responds with success' do
              set_current_user(user)
              get :show, id: ownership.bike_id
              expect(response.status).to eq(200)
              expect(response).to render_template(:show)
              expect(response).to render_with_layout('application_revised')
              expect(assigns(:bike)).to be_decorated
              expect(flash).to_not be_present
            end
          end
          context 'Admin viewing' do
            it 'responds with success' do
              set_current_user(FactoryGirl.create(:admin))
              get :show, id: ownership.bike_id
              expect(response.status).to eq(200)
              expect(response).to render_template(:show)
              expect(response).to render_with_layout('application_revised')
              expect(assigns(:bike)).to be_decorated
              expect(flash).to_not be_present
            end
          end
          context 'non-owner non-admin viewing' do
            it 'redirects' do
              set_current_user(FactoryGirl.create(:user))
              get :show, id: bike.id
              expect(response).to redirect_to(:root)
              expect(flash[:error]).to be_present
            end
          end
        end
      end
      context 'too large of integer bike_id' do
        it 'responds with not found' do
          expect do
            get :show, id: 57549641769762268311552
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
    context 'qr code gif' do
      it 'renders' do
        get :show, id: bike.id, format: :gif
        expect(response.status).to eq(200)
      end
    end
  end

  describe 'spokecard' do
    it 'renders the page from bike id' do
      bike = FactoryGirl.create(:bike)
      get :spokecard, id: bike.id
      expect(response.code).to eq('200')
    end
  end

  describe 'scanned' do
    it 'renders the page from bike id' do
      bike = FactoryGirl.create(:bike)
      get :scanned, id: bike.id
      expect(response).to redirect_to bike_url(bike)
    end
    it 'redirects to the proper page' do
      bike = FactoryGirl.create(:bike, card_id: 2)
      get :scanned, card_id: bike.card_id
      expect(response).to redirect_to bike_url(bike)
    end
    it "renders a page if there isn't a connection" do
      get :scanned, card_id: 12
      expect(response.code).to eq('200')
    end
  end

  describe 'new' do
    context 'not signed in' do
      it 'sets redirect_to' do
        get :new, stolen: true, b_param_token: 'cool-token-thing'
        expect(response).to redirect_to new_user_url
        # expect(Rack::Utils.parse_query(session[:discourse_redirect])).to eq(discourse_params)
        expect(flash[:info]).to be_present
        expect(session[:return_to]).to eq new_bike_path(stolen: true, b_param_token: 'cool-token-thing')
      end
    end

    context 'signed in' do
      include_context :logged_in_as_user
      let(:manufacturer) { FactoryGirl.create(:manufacturer) }
      let(:color) { FactoryGirl.create(:color) }
      context 'passed stolen param' do
        it 'renders a new stolen bike' do
          get :new, stolen: true
          expect(response.code).to eq('200')
          expect(assigns(:bike).stolen).to be_truthy
        end
      end
      context 'passed recovered param' do
        it 'renders a new recovered bike' do
          get :new, recovered: true
          expect(response.code).to eq('200')
          expect(assigns(:bike).recovered).to be_truthy
        end
      end
      context 'stolen from params' do
        it 'renders a new stolen bike' do
          get :new, stolen: true
          expect(response.code).to eq('200')
          expect(assigns(:bike).stolen).to be_truthy
          b_param = assigns(:b_param)
          expect(b_param.revised_new?).to be_truthy
          expect(response).to render_template(:new)
          expect(response).to render_with_layout('application_revised')
        end
      end
      context 'bike through b_param' do
        let(:bike_attrs) do
          {
            manufacturer_id: manufacturer.id,
            primary_frame_color_id: color.id,
            owner_email: 'something@stuff.com'
          }
        end
        context 'valid b_param' do
          it 'renders the bike from b_param' do
            b_param = BParam.create(params: { bike: bike_attrs.merge('revised_new' => true) })
            expect(b_param.id_token).to be_present
            get :new, b_param_token: b_param.id_token
            bike = assigns(:bike)
            expect(assigns(:b_param)).to eq b_param
            expect(bike.is_a?(Bike)).to be_truthy
            bike_attrs.each { |k, v| expect(bike.send(k)).to eq(v) }
            expect(response).to render_with_layout('application_revised')
          end
        end
        context 'partial registration by organization' do
          let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
          let(:organized_bike_attrs) { bike_attrs.merge(creation_organization_id: organization.id) }
          it 'renders for the user (even though a different creator)' do
            b_param = BParam.create(params: { bike: organized_bike_attrs.merge('revised_new' => true) })
            expect(b_param.id_token).to be_present
            get :new, b_param_token: b_param.id_token
            bike = assigns(:bike)
            expect(assigns(:b_param)).to eq b_param
            expect(bike.is_a?(Bike)).to be_truthy
            organized_bike_attrs.each do |k, v|
              pp k unless bike.send(k) == v
              expect(bike.send(k)).to eq(v)
            end
            expect(response).to render_with_layout('application_revised')
          end
        end
        context 'invalid b_param' do
          it 'renders a new bike, has a flash message' do
            b_param = BParam.create(creator_id: FactoryGirl.create(:user).id)
            expect(b_param.id_token).to be_present
            get :new, b_param_token: b_param.id_token
            bike = assigns(:bike)
            expect(bike.is_a?(Bike)).to be_truthy
            expect(assigns(:b_param)).to_not eq b_param
            expect(response).to render_with_layout('application_revised')
            expect(flash[:error]).to match(/sorry/i)
          end
        end
      end
    end
  end

  describe 'create' do
    # This is the create action for bikes controller
    let(:manufacturer) { FactoryGirl.create(:manufacturer) }
    let(:color) { FactoryGirl.create(:color) }
    let(:cycle_type) { FactoryGirl.create(:cycle_type) }
    let(:handlebar_type) { FactoryGirl.create(:handlebar_type) }

    describe 'embeded' do
      let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
      let(:user) { organization.auto_user }
      let(:b_param) { BParam.create(creator_id: organization.auto_user.id, params: { creation_organization_id: organization.id, embeded: true }) }
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
          expect(bike.creation_state.origin).to eq 'embed'
          expect(bike.creation_state.organization).to eq organization
          expect(bike.creation_state.creator).to eq bike.creator
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
            date_stolen_input: Time.now.to_date.strftime('%m-%d-%Y')
          }
        end
        context 'valid' do
          it 'creates a new ownership and bike from an organization' do
            # pp stolen_params[:date_stolen_input]
            expect do
              post :create, bike: bike_params.merge(stolen: true), stolen_record: stolen_params
            end.to change(Ownership, :count).by 1
            bike = Bike.last
            expect(bike.creation_state.origin).to eq 'embed'
            expect(bike.creation_state.organization).to eq organization
            expect(bike.creation_state.creator).to eq bike.creator
            testable_bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v.to_s }
            stolen_record = bike.current_stolen_record
            stolen_params.except(:date_stolen_input).each { |k, v| expect(stolen_record.send(k).to_s).to eq v.to_s }
            expect(stolen_record.date_stolen.to_date).to eq Time.now.to_date
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
          manufacturer_id: manufacturer.slug,
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
            bike = Bike.last
            expect(bike.owner_email).to eq bike_params[:owner_email].downcase
            expect(bike.creation_state.origin).to eq 'embed_extended'
            expect(bike.creation_state.organization).to eq organization
            expect(bike.creation_state.creator).to eq bike.creator
            expect(bike.manufacturer).to eq manufacturer
          end
        end
      end
      context 'with persisted email' do
        it 'registers a bike and redirects with persist_email' do
          post :create, bike: bike_params.merge(manufacturer_id: 'A crazy different thing'), persist_email: true
          expect(response).to redirect_to(embed_extended_organization_url(organization, email: 'flow@goodtimes.com'))
          bike = Bike.last
          expect(bike.creation_state.origin).to eq 'embed_extended'
          expect(bike.creation_state.organization).to eq organization
          expect(bike.creation_state.creator).to eq bike.creator
          expect(bike.manufacturer).to eq Manufacturer.other
          expect(bike.manufacturer_other).to eq 'A crazy different thing'
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
            manufacturer_id: manufacturer.name,
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
            b_param = BParam.create(params: { 'bike' => bike_params }, origin: 'embed_partial')
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
            expect(bike.creation_state.origin).to eq 'embed_partial'
            expect(bike.creation_state.creator).to eq bike.creator
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

  describe 'edit' do
    let(:ownership) { FactoryGirl.create(:ownership) }
    let(:bike) { ownership.bike }
    let(:edit_templates) do
      {
        root: 'Bike Details',
        photos: 'Photos',
        drivetrain: 'Wheels + Drivetrain',
        accessories: 'Accessories + Components',
        ownership: 'Groups + Ownership',
        remove: 'Hide or Delete'
      }
    end
    let(:non_stolen_edit_templates) { edit_templates.merge(stolen: 'Report Stolen or Missing') }
    let(:stolen_edit_templates) { { stolen: 'Theft details' }.merge(edit_templates) }
    let(:recovery_edit_templates) { { stolen: 'Recovery details' }.merge(edit_templates) }

    context 'no user' do
      it 'redirects and sets the flash' do
        get :edit, id: bike.id
        expect(response).to redirect_to bike_path(bike)
        expect(flash[:error]).to be_present
      end
    end
    context 'user present' do
      let(:user) { FactoryGirl.create(:user) }
      before { set_current_user(user) }
      context "user present but isn't allowed to edit the bike" do
        it 'redirects and sets the flash' do
          FactoryGirl.create(:user)
          get :edit, id: bike.id
          expect(response).to redirect_to bike_path(bike)
          expect(flash[:error]).to be_present
        end
      end
      context "user present but hasn't claimed the bike" do
        it 'claims and renders' do
          ownership.update_attribute :user_id, user.id
          expect(bike.owner).to_not eq user
          get :edit, id: bike.id
          bike.reload
          expect(bike.owner).to eq user
          expect(response).to be_success
          expect(assigns(:edit_template)).to eq 'root'
        end
      end
      context 'not-creator but member of creation_organization' do
        let(:ownership) { FactoryGirl.create(:organization_ownership) }
        let(:organization) { bike.creation_organization }
        let(:user) { FactoryGirl.create(:organization_member, organization: organization) }
        it 'renders' do
          expect(bike.owner).to_not eq user
          expect(bike.creation_organization).to eq user.organizations.first
          get :edit, id: bike.id
          expect(response).to be_success
          expect(assigns(:edit_template)).to eq 'root'
        end
      end
    end
    context 'user allowed to edit the bike' do
      let(:user) { ownership.creator }
      context 'revised' do
        before { set_current_user(user) }
        context 'root' do
          context 'non-stolen bike' do
            it 'renders the bike_details template' do
              get :edit, id: bike.id
              expect(response).to render_with_layout 'application_revised'
              expect(response).to be_success
              expect(assigns(:edit_template)).to eq 'root'
              expect(assigns(:edit_templates)).to eq non_stolen_edit_templates.as_json
              expect(response).to render_template 'edit_root'
            end
          end
          context 'stolen bike' do
            it 'renders with stolen as first template, different description' do
              bike.update_attribute :stolen, true
              bike.reload
              expect(bike.stolen).to be_truthy
              get :edit, id: bike.id
              expect(response).to render_with_layout 'application_revised'
              expect(response).to be_success
              expect(assigns(:edit_template)).to eq 'stolen'
              expect(assigns(:edit_templates)).to eq stolen_edit_templates.as_json
              expect(response).to render_template 'edit_stolen'
            end
          end
          context 'recovered bike' do
            it 'renders with recovered as first template, different description' do
              bike.update_attributes(stolen: true, recovered: true)
              bike.reload
              expect(bike.recovered).to be_truthy
              get :edit, id: bike.id
              expect(response).to render_with_layout 'application_revised'
              expect(response).to be_success
              expect(assigns(:edit_template)).to eq 'stolen'
              expect(assigns(:edit_templates)).to eq recovery_edit_templates.as_json
              expect(response).to render_template 'edit_stolen'
            end
          end
        end
        # Grab all the template keys from the controller so we can test that we render all of them
        # Both to ensure we get all of them and because we can't use the let block
        bc = BikesController.new
        bc.instance_variable_set(:@bike, Bike.new)
        bc.edit_templates_hash.keys.map(&:to_s).each do |template|
          context template do
            it 'renders the template' do
              get :edit, id: bike.id, page: template
              expect(response).to render_with_layout('application_revised')
              expect(response).to be_success
              expect(response).to render_template("edit_#{template}")
              expect(assigns(:edit_template)).to eq(template)
              expect(assigns(:private_images)).to eq([]) if template == 'photos'
            end
          end
        end
      end
    end
  end

  describe 'update' do
    context 'user is present but is not allowed to edit' do
      it 'does not update and redirects' do
        ownership = FactoryGirl.create(:ownership)
        user = FactoryGirl.create(:user)
        set_current_user(user)
        put :update, id: ownership.bike.id, bike: { serial_number: '69' }
        expect(response).to redirect_to bike_url(ownership.bike)
        expect(flash[:error]).to be_present
      end
    end

    context 'creator present (who is allowed to edit)' do
      let(:ownership) { FactoryGirl.create(:ownership) }
      let(:user) { ownership.creator }
      let(:bike) { ownership.bike }
      before do
        set_current_user(user)
      end
      context 'legacy' do
        it 'allows you to edit an example bike' do
          # Also test that we don't don't blank bike_organizations
          # if bike_organization_ids aren't passed
          organization = FactoryGirl.create(:organization)
          ownership.bike.update_attributes(example: true, bike_organization_ids: [organization.id])
          bike.reload
          expect(bike.bike_organization_ids).to eq([organization.id])
          put :update, id: bike.id, bike: { description: '69' }
          expect(response).to redirect_to edit_bike_url(bike)
          bike.reload
          expect(bike.description).to eq('69')
          expect(bike.bike_organization_ids).to eq([organization.id])
        end

        it 'updates the bike and components' do
          component_1 = FactoryGirl.create(:component, bike: bike)
          handlebar_type_id = FactoryGirl.create(:handlebar_type).id
          ctype_id = component_1.ctype_id
          bike.reload
          component_2_attrs = {
            _destroy: '0',
            ctype_id: ctype_id,
            description: 'sdfsdfsdf',
            manufacturer_id: bike.manufacturer_id.to_s,
            manufacturer_other: 'stuffffffff',
            cmodel_name: 'asdfasdf',
            year: '1995',
            serial_number: 'simple_serial'
          }
          bike_attrs = {
            description: '69',
            handlebar_type_id: handlebar_type_id,
            components_attributes: {
              '0' => {
                '_destroy' => '1',
                id: component_1.id.to_s
              },
              Time.zone.now.to_i.to_s => component_2_attrs
            }
          }
          put :update, id: bike.id, bike: bike_attrs
          bike.reload
          expect(bike.description).to eq('69')
          expect(response).to redirect_to edit_bike_url(bike)
          expect(bike.handlebar_type_id).to eq handlebar_type_id
          expect(assigns(:bike)).to be_decorated
          expect(bike.hidden).to be_falsey

          expect(bike.components.count).to eq 1
          expect(bike.components.where(id: component_1.id).any?).to be_falsey
          component_2 = bike.components.first
          component_2_attrs.except(:_destroy).each do |key, value|
            expect(component_2.send(key).to_s).to eq value.to_s
          end
        end

        it 'marks the bike unhidden' do
          bike.update_attribute :marked_user_hidden, '1'
          bike.reload
          expect(bike.hidden).to be_truthy
          put :update, id: bike.id, bike: { marked_user_unhidden: 'true' }
          expect(bike.reload.hidden).to be_falsey
        end

        it 'creates a new ownership if the email changes' do
          expect do
            put :update, id: bike.id, bike: { owner_email: 'new@email.com' }
          end.to change(Ownership, :count).by(1)
        end

        it "redirects to return_to if it's a valid url" do
          session[:return_to] = '/about'
          put :update, id: bike.id, bike: { description: '69', marked_user_hidden: '0' }
          expect(bike.reload.description).to eq('69')
          expect(response).to redirect_to '/about'
          expect(session[:return_to]).to be_nil
        end

        it "doesn't redirect and clears the session if not a valid url" do
          session[:return_to] = 'http://testhost.com/bad_place'
          put :update, id: bike.id, bike: { description: '69', marked_user_hidden: '0' }
          bike.reload
          expect(bike.description).to eq('69')
          expect(session[:return_to]).to be_nil
          expect(response).to redirect_to edit_bike_url
        end
      end
      context 'revised' do
        # We're testing a few things in here:
        # Firstly, new stolen update code paths
        # Also, that we can apply stolen changes to hidden bikes
        # And finally, that it redirects to the correct page
        context 'stolen update' do
          let(:state) { FactoryGirl.create(:state) }
          let(:country) { state.country }
          let(:stolen_record) { FactoryGirl.create(:stolen_record, bike: bike, city: 'party') }
          let(:stolen_attrs) do
            {
              date_stolen_input: 'Mon Feb 8 2016',
              phone: '9999999999',
              street: '66666666 foo street',
              country_id: country.id,
              city: 'Chicago',
              zipcode: '60647',
              state_id: state.id,
              locking_description: 'Some description',
              lock_defeat_description: 'It was cuttttt',
              theft_description: 'Someone stole it and stuff',
              police_report_number: '#444444',
              police_report_department: 'department of party',
              secondary_phone: '8888888888',
              proof_of_ownership: 1,
              receive_notifications: 0
            }
          end
          let(:bike_attrs) do
            {
              stolen: true,
              stolen_records_attributes: {
                '0' => stolen_attrs
              }
            }
          end
          let(:skipped_attrs) { %w(proof_of_ownership receive_notifications date_stolen_input).map(&:to_sym) }
          it 'updates and returns to the right page' do
            bike.update_attribute :stolen, true
            bike.reload
            expect(bike.stolen).to be_truthy
            # bike.save
            expect(stolen_record.date_stolen).to be_present
            expect(stolen_record.proof_of_ownership).to be_falsey
            expect(stolen_record.receive_notifications).to be_truthy
            # bike.reload
            # bike.update_attributes(stolen: true, current_stolen_record_id: stolen_record.id)
            bike.reload
            expect(bike.find_current_stolen_record).to eq stolen_record
            put :update, id: bike.id, bike: bike_attrs, edit_template: 'fancy_template'
            expect(flash[:error]).to_not be_present
            expect(response).to redirect_to edit_bike_url(page: 'fancy_template')
            bike.reload
            expect(bike.stolen).to be_truthy
            # expect(bike.hidden).to be_truthy
            # Stupid cheat because we're creating an extra record here for fuck all reason
            current_stolen_record = bike.find_current_stolen_record
            expect(bike.stolen_records.count).to eq 1
            expect(bike.find_current_stolen_record.id).to eq stolen_record.id
            # stolen_record.reload
            expect(bike.find_current_stolen_record.id).to eq stolen_record.id
            expect(current_stolen_record.date_stolen).to be_within(1.second).of DateTime.strptime('02-08-2016 06', '%m-%d-%Y %H')
            expect(current_stolen_record.proof_of_ownership).to be_truthy
            expect(current_stolen_record.receive_notifications).to be_falsey
            stolen_attrs.except(*skipped_attrs).each do |key, value|
              pp key unless current_stolen_record.send(key) == value
              expect(current_stolen_record.send(key)).to eq value
            end
          end
          context 'recovered bike' do
            it 'marks the bike recovered'
          end
        end
      end
    end
    context 'owner present (who is allowed to edit)' do
      let(:color) { FactoryGirl.create(:color) }
      let(:user) { FactoryGirl.create(:confirmed_user) }
      let(:ownership) { FactoryGirl.create(:organization_ownership, owner_email: user.email) }
      let(:bike) { ownership.bike }
      let(:organization) { bike.organizations.first }
      let(:organization_2) { FactoryGirl.create(:organization) }
      let(:allowed_attributes) do
        {
          description: '69 description',
          marked_user_hidden: '0',
          primary_frame_color_id: color.id,
          secondary_frame_color_id: color.id,
          tertiary_frame_color_id: Color.black.id,
          handlebar_type_id: HandlebarType.flat.id,
          coaster_brake: true,
          belt_drive: true,
          front_gear_type_id: FactoryGirl.create(:front_gear_type).id,
          rear_gear_type_id: FactoryGirl.create(:rear_gear_type).id,
          owner_email: 'new_email@stuff.com',
          year: 1993,
          frame_model: 'A sweet model named things',
          frame_material_id: FrameMaterial.steel.id,
          frame_size: '56cm',
          name: 'a sweet name for a bike',
          additional_registration: 'some weird other number',
          bike_organization_ids: "#{organization_2.id}, #{organization.id}"
        }
      end
      let(:skipped_attrs) { %w(marked_user_hidden bike_organization_ids).map(&:to_sym) }
      before do
        ownership.mark_claimed
        set_current_user(user)
        expect(ownership.owner).to eq user
      end
      it 'updates the bike with the allowed_attributes' do
        put :update, id: bike.id, bike: allowed_attributes
        expect(response).to redirect_to edit_bike_url(bike)
        expect(assigns(:bike)).to be_decorated
        bike.reload
        expect(bike.hidden).to be_falsey
        allowed_attributes.except(*skipped_attrs).each do |key, value|
          pp value, key unless bike.send(key) == value
          expect(bike.send(key)).to eq value
        end
        expect(bike.bike_organization_ids).to eq([organization.id, organization_2.id])
      end
    end
  end
end
