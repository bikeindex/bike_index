require 'spec_helper'

describe BikesController do
  describe 'index' do
    context 'no subdomain' do
      context 'legacy' do
        it 'renders' do
          get :index
          expect(response.status).to eq(200)
          expect(assigns(:location)).to_not be_present
          expect(flash).to_not be_present
          expect(assigns(:per_page)).to eq 10
        end
      end
      context 'revised' do
        context 'no params' do
          it 'renders' do
            get :index
            expect(response.status).to eq(200)
            expect(response).to render_template(:index)
            expect(response).to render_with_layout('application_revised')
            expect(flash).to_not be_present
            expect(assigns(:location)).to_not be_present
            expect(assigns(:per_page)).to eq 10
            expect(assigns(:stolenness)).to eq 'stolen'
          end
        end
        context 'default parameters (in the HTML)' do
          it 'renders stolen, non-proximity' do
            get :index,
                utf8: '✓',
                query: '',
                proximity: 'Chicago',
                proximity_radius: '100',
                stolen: 'true',
                non_stolen: '',
                non_proximity: true
            expect(response.status).to eq(200)
            expect(response).to render_with_layout('application_revised')
            expect(assigns(:location)).to_not be_present
            expect(flash).to_not be_present
            expect(assigns(:per_page)).to eq 10
            expect(assigns(:stolenness)).to eq 'stolen'
          end
        end
        context 'proximity' do
          it 'renders, assigns location via geocoder' do
            # Without a matching current stolen record, it doesn't go whole way through proximity
            FactoryGirl.create(:stolen_bike)
            get :index, proximity: 'ip', stolen: true
            expect(response.status).to eq(200)
            expect(flash).to_not be_present
            expect(assigns(:per_page)).to eq 10
            target_location = [ { data: default_location, cache_hit: nil } ].as_json # in spec_helper
            expect(assigns(:location).as_json).to eq target_location
            expect(assigns(:stolenness)).to eq 'stolen_proximity'
            expect(response).to render_with_layout('application_revised')
          end
        end
        context 'serial_param' do
          it 'renders' do
            manufacturer = FactoryGirl.create(:manufacturer)
            color = FactoryGirl.create(:color)
            get :index,
                query: "c_#{color.id},s#serialzzzzzz#,m_#{manufacturer.id}",
                stolen: '',
                non_stolen: 'true'
            expect(response.status).to eq(200)
            target_selectize_items = [
              manufacturer.autocomplete_result_hash,
              color.autocomplete_result_hash,
              { id: 'serial', search_id: 's#serialzzzzzz#', text: 'serialzzzzzz' }
            ].as_json
            expect(assigns(:selectize_items)).to eq target_selectize_items
            expect(assigns(:stolenness)).to eq 'non_stolen'
            expect(response).to render_with_layout('application_revised')
          end
        end
        context 'problematic deserialization params' do
          it 'renders and correctly deserializes serial' do
            get :index,
                utf8: '✓',
                query: 's#R910860723#',
                proximity: 'ip',
                proximity_radius: '100',
                stolen: 'true',
                non_stolen: '',
                non_proximity: ''
            expect(response.status).to eq(200)
            target_selectize_items = [
              { id: 'serial', search_id: 's#R910860723#', text: 'R910860723' }
            ].as_json
            expect(assigns(:selectize_items)).to eq target_selectize_items
            expect(assigns(:stolenness)).to eq 'stolen_proximity'
            expect(response).to render_with_layout('application_revised')
          end
        end
      end
    end
    context 'with subdomain' do
      it 'redirects to no subdomain' do
        @request.host = 'stolen.example.com'
        get :index
        expect(response).to redirect_to bikes_url(subdomain: false)
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
    let(:user) { FactoryGirl.create(:user) }
    context 'legacy' do
      before do
        CycleType.bike
        PropulsionType.foot_pedal
      end

      it 'renders a new stolen bike' do
        set_current_user(user)
        get :new, stolen: true
        expect(response.code).to eq('200')
        expect(assigns(:bike).stolen).to be_truthy
      end

      it 'renders a new recovered bike' do
        set_current_user(user)
        get :new, recovered: true
        expect(response.code).to eq('200')
        expect(assigns(:bike).recovered).to be_truthy
      end

      it 'renders a new organization bike' do
        organization = FactoryGirl.create(:organization)
        FactoryGirl.create(:membership, user: user, organization: organization)
        set_current_user(user)
        get :new
        expect(response.code).to eq('200')
      end
    end

    context 'revised layout' do
      before do
        # instantiate the required bike attrs... there is a better way to do this.
        CycleType.bike
        PropulsionType.foot_pedal
        set_current_user(user)
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
        context 'valid b_param' do
          it 'renders the bike from b_param' do
            manufacturer = FactoryGirl.create(:manufacturer)
            color = FactoryGirl.create(:color)
            bike_attrs = {
              manufacturer_id: manufacturer.id,
              primary_frame_color_id: color.id,
              owner_email: 'something@stuff.com'
            }
            b_param = BParam.create(params: { bike: bike_attrs.merge(revised_new: true) })
            expect(b_param.id_token).to be_present
            get :new, b_param_token: b_param.id_token
            bike = assigns(:bike)
            expect(assigns(:b_param)).to eq b_param
            expect(bike.is_a?(Bike)).to be_truthy
            bike_attrs.each { |k, v| expect(bike.send(k)).to eq(v) }
            expect(response).to render_with_layout('application_revised')
          end
        end
        context 'invalid b_param' do
          it 'renders a new bike, has a flash message' do
            b_param = BParam.create(creator_id: FactoryGirl.create(:user).id)
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
    before do
      # instantiate the required bike attrs... there is a better way to do this.
      CycleType.bike
      PropulsionType.foot_pedal
    end
    context 'legacy' do
      describe 'web interface submission' do
        before :each do
          @user = FactoryGirl.create(:user)
          @b_param = FactoryGirl.create(:b_param, creator: @user)
          manufacturer = FactoryGirl.create(:manufacturer)
          set_current_user(@user)
          @bike = { serial_number: '1234567890',
                    b_param_id_token: @b_param.id_token,
                    cycle_type_id: FactoryGirl.create(:cycle_type).id,
                    manufacturer_id: manufacturer.id,
                    rear_tire_narrow: 'true',
                    rear_wheel_size_id: FactoryGirl.create(:wheel_size).id,
                    primary_frame_color_id: FactoryGirl.create(:color).id,
                    handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
                    owner_email: @user.email
          }
        end

        it "does not use the b_param if isn't owned by user" do
          user = FactoryGirl.create(:user)
          set_current_user(user)
          post :create, bike: @bike
          @b_param.reload
          expect(@b_param.created_bike_id).to_not be_present
        end

        it 'creates a new stolen bike' do
          FactoryGirl.create(:country, iso: 'US')
          @bike[:phone] = '312.379.9513'
          expect do
            post :create, stolen: 'true', bike: @bike
          end.to change(StolenRecord, :count).by(1)
          expect(@b_param.reload.created_bike_id).not_to be_nil
          expect(@b_param.reload.bike_errors).to be_nil
          expect(@user.reload.phone).to eq('3123799513')
        end

        it 'creates a new ownership and bike from an organization' do
          organization = FactoryGirl.create(:organization)
          FactoryGirl.create(:membership, user: @user, organization: organization)
          @bike[:creation_organization_id] = organization.id
          expect do
            post :create, bike: @bike
          end.to change(Ownership, :count).by(1)
          expect(Bike.last.creation_organization_id).to eq(organization.id)
        end
      end

      describe 'embeded submission' do
        it 'creates a new ownership and bike from an organization' do
          organization = FactoryGirl.create(:organization)
          user = FactoryGirl.create(:user)
          FactoryGirl.create(:membership, user: user, organization: organization)
          organization.save
          manufacturer = FactoryGirl.create(:manufacturer)
          b_param = BParam.create(creator_id: organization.auto_user.id, params: { creation_organization_id: organization.id, embeded: true })
          bike = { serial_number: '69',
                   b_param_id_token: b_param.id_token,
                   creation_organization_id: organization.id,
                   embeded: true,
                   additional_registration: 'Testly secondary',
                   cycle_type_id: FactoryGirl.create(:cycle_type).id,
                   manufacturer_id: manufacturer.id,
                   primary_frame_color_id: FactoryGirl.create(:color).id,
                   handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
                   owner_email: 'Flow@goodtimes.com'
          }
          expect do
            post :create, bike: bike
          end.to change(Ownership, :count).by(1)
          bike = Bike.last
          expect(bike.creation_organization_id).to eq(organization.id)
          expect(bike.additional_registration).to eq('Testly secondary')
        end
      end

      describe 'extended embeded submission' do
        it 'registers a bike and uploads an image' do
          Sidekiq::Testing.inline! do
            organization = FactoryGirl.create(:organization)
            user = FactoryGirl.create(:user)
            FactoryGirl.create(:membership, user: user, organization: organization)
            organization.save
            manufacturer = FactoryGirl.create(:manufacturer)
            b_param = BParam.create(creator_id: organization.auto_user.id, params: { creation_organization_id: organization.id, embeded: true })
            test_photo = Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg')))
            expect_any_instance_of(ImageAssociatorWorker).to receive(:perform).and_return(true)
            bike = { serial_number: '69',
                     b_param_id_token: b_param.id_token,
                     creation_organization_id: organization.id,
                     embeded: true,
                     embeded_extended: true,
                     cycle_type_id: FactoryGirl.create(:cycle_type).id,
                     manufacturer_id: manufacturer.id,
                     primary_frame_color_id: FactoryGirl.create(:color).id,
                     handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
                     owner_email: 'Flow@goodtimes.com',
                     image: test_photo
            }
            post :create, bike: bike
            expect(response).to redirect_to(embed_extended_organization_url(organization))
          end
        end
      end

      describe 'extended embed submission with persisted email' do
        it 'registers a bike and redirects with persist_email' do
          organization = FactoryGirl.create(:organization)
          user = FactoryGirl.create(:user)
          FactoryGirl.create(:membership, user: user, organization: organization)
          organization.save
          manufacturer = FactoryGirl.create(:manufacturer)
          b_param = BParam.create(creator_id: organization.auto_user.id, params: { creation_organization_id: organization.id, embeded: true })
          bike = { serial_number: '69',
                   b_param_id_token: b_param.id_token,
                   creation_organization_id: organization.id,
                   embeded: true,
                   embeded_extended: true,
                   cycle_type_id: FactoryGirl.create(:cycle_type).id,
                   manufacturer_id: manufacturer.id,
                   primary_frame_color_id: FactoryGirl.create(:color).id,
                   handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
                   owner_email: 'Flow@goodtimes.com'
          }
          post :create, bike: bike, persist_email: true
          expect(response).to redirect_to(embed_extended_organization_url(organization, email: 'flow@goodtimes.com'))
        end
      end
    end

    context 'revised' do
      let(:user) { FactoryGirl.create(:user) }
      let(:manufacturer) { FactoryGirl.create(:manufacturer) }
      let(:color) { FactoryGirl.create(:color) }
      before do
        set_current_user(user)
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
            bb_data = { bike: { rear_wheel_bsd: wheel_size.iso_bsd.to_s }, components: [] }
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
            }
            b_param = BParam.create(params: { bike: bike_params })
            bb_data = { bike: { } }
            # We need to call clean_params on the BParam after bikebook update, so that
            # the foreign keys are assigned correctly. This is how we test that we're 
            # This is also where we're testing bikebook assignment
            expect_any_instance_of(BikeBookIntegration).to receive(:get_model) { bb_data }
            expect do
              post :create, bike: { manufacturer_id: manufacturer.slug, b_param_id_token: b_param.id_token }
            end.to change(Bike, :count).by(1)
            expect(flash[:success]).to be_present
            bike = Bike.last
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
            expect(response).to redirect_to(edit_bike_url(bike))
          end
        end
      end
    end
  end

  describe 'edit' do
    let(:ownership) { FactoryGirl.create(:ownership) }
    let(:bike) { ownership.bike }
    context 'when there is no user' do
      it 'redirects and sets the flash' do
        get :edit, id: bike.id
        expect(response).to redirect_to bike_path(bike)
        expect(flash[:error]).to be_present
      end
    end
    context "when a user is present but isn't allowed to edit the bike" do
      it 'redirects and sets the flash' do
        user = FactoryGirl.create(:user)
        set_current_user(user)
        get :edit, id: bike.id
        expect(response).to redirect_to bike_path(bike)
        expect(flash[:error]).to be_present
      end
    end
    context 'user allowed to edit the bike' do
      let(:user) { ownership.creator }

      context 'revised' do
        before do
          set_current_user(user)
        end
        context 'root' do
          context 'non-stolen bike' do
            it 'renders the bike_details template' do
              edit_templates = {
                root: 'Bike Details',
                photos: 'Photos',
                drivetrain: 'Wheels + Drivetrain',
                accessories: 'Accessories + Components',
                ownership: 'Change Owner or Delete',
                stolen: 'Report Stolen or Missing'
              }.as_json
              get :edit, id: bike.id
              expect(response).to render_with_layout 'application_revised'
              expect(response).to be_success
              expect(assigns(:edit_template)).to eq 'root'
              expect(assigns(:edit_templates)).to eq edit_templates
              expect(response).to render_template 'edit_root'
            end
          end
          context 'stolen bike' do
            it 'renders with stolen as first template, different description' do
              edit_templates = {
                stolen: 'Theft details',
                root: 'Bike Details',
                photos: 'Photos',
                drivetrain: 'Wheels + Drivetrain',
                accessories: 'Accessories + Components',
                ownership: 'Change Owner or Delete'
              }.as_json
              bike.update_attribute :stolen, true
              bike.reload
              expect(bike.stolen).to be_truthy
              get :edit, id: bike.id
              expect(response).to render_with_layout 'application_revised'
              expect(response).to be_success
              expect(assigns(:edit_template)).to eq 'stolen'
              expect(assigns(:edit_templates)).to eq edit_templates
              expect(response).to render_template 'edit_stolen'
            end
          end
          context 'recovered bike' do
            it 'renders with recovered as first template, different description' do
              edit_templates = {
                stolen: 'Recovery details',
                root: 'Bike Details',
                photos: 'Photos',
                drivetrain: 'Wheels + Drivetrain',
                accessories: 'Accessories + Components',
                ownership: 'Change Owner or Delete'
              }.as_json
              bike.update_attributes(stolen: true, recovered: true)
              bike.reload
              expect(bike.recovered).to be_truthy
              get :edit, id: bike.id
              expect(response).to render_with_layout 'application_revised'
              expect(response).to be_success
              expect(assigns(:edit_template)).to eq 'stolen'
              expect(assigns(:edit_templates)).to eq edit_templates
              expect(response).to render_template 'edit_stolen'
            end
          end
        end
        %w(root photos drivetrain accessories ownership stolen).each do |template|
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
      before do
        ownership = FactoryGirl.create(:ownership)
        user = FactoryGirl.create(:user)
        set_current_user(user)
        put :update, id: ownership.bike.id, bike: { serial_number: '69' }
      end
      it { is_expected.to respond_with(:redirect) }
      it { is_expected.to redirect_to(bike_url) }
      it { is_expected.to set_flash }
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
          ownership.bike.update_attributes(example: true)
          put :update, id: bike.id, bike: { description: '69' }
          expect(response).to redirect_to edit_bike_url(bike)
          bike.reload
          expect(bike.description).to eq('69')
        end

        it 'updates the bike' do
          put :update, id: bike.id, bike: { description: '69', marked_user_hidden: '0' }
          bike.reload
          expect(bike.description).to eq('69')
          expect(response).to redirect_to edit_bike_url(bike)
          expect(assigns(:bike)).to be_decorated
          expect(bike.hidden).to be_falsey
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
        it 'updates and returns to the right page' do
          stolen_record = FactoryGirl.create(:stolen_record, bike: bike, city: 'party')
          bike.stolen = true
          # bike.marked_user_hidden = true
          bike.save
          expect(stolen_record.date_stolen).to be_present
          bike.reload
          # bike.update_attributes(stolen: true, current_stolen_record_id: stolen_record.id)
          bike.reload
          expect(bike.find_current_stolen_record).to eq stolen_record
          put :update,
              id: bike.id,
              edit_template: 'fancy_template',
              bike: {
                stolen: true,
                stolen_records_attributes: {
                  stolen_record.id.to_s => {
                    date_stolen_input: 'Mon Feb 22 2016',
                    phone: '9999999999',
                    street: '66666666 foo street'
                  }
                }
              }
          expect(flash[:error]).to_not be_present
          expect(response).to redirect_to edit_bike_url(page: 'fancy_template')
          bike.reload
          expect(bike.stolen).to be_truthy
          # expect(bike.hidden).to be_truthy
          # Stupid cheat because we're creating an extra record here for fuck all reason
          current_stolen_record = bike.find_current_stolen_record

          # expect(bike.stolen_records.count).to eq 1
          # stolen_record.reload
          # expect(bike.find_current_stolen_record.id).to eq stolen_record.id
          # stolen_record.reload
          expect(current_stolen_record.phone).to eq '9999999999'
          # expect(current_stolen_record.city).to eq 'party'
          expect(current_stolen_record.street).to eq '66666666 foo street'
          expect(current_stolen_record.date_stolen).to eq DateTime.strptime('02-22-2016 06', '%m-%d-%Y %H')
        end
      end
    end
    context 'owner present (who is allowed to edit)' do
      let(:user) { FactoryGirl.create(:confirmed_user) }
      let(:ownership) { FactoryGirl.create(:ownership, owner_email: user.email) }
      let(:bike) { ownership.bike }
      before do
        ownership.mark_claimed
        set_current_user(user)
        expect(ownership.owner).to eq user
      end
      it 'updates the bike' do
        put :update, id: bike.id, bike: { description: '69', marked_user_hidden: '0' }
        bike.reload
        expect(bike.description).to eq('69')
        expect(response).to redirect_to edit_bike_url(bike)
        expect(assigns(:bike)).to be_decorated
        expect(bike.hidden).to be_falsey
      end
    end
  end
end
