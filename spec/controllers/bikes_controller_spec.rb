require 'spec_helper'

describe BikesController do
  describe 'index' do
    context 'no subdomain' do
      before do
        get :index
      end
      it { is_expected.to respond_with(:success) }
      it { is_expected.to render_template(:index) }
      it { is_expected.not_to set_flash }

      it 'sets per_page correctly' do
        expect(assigns(:per_page)).to eq 10
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
    describe 'showing' do
      before do
        ownership = FactoryGirl.create(:ownership)
        get :show, id: ownership.bike.id
      end
      it { is_expected.to respond_with(:success) }
      it { is_expected.to render_template(:show) }
      it { is_expected.not_to set_flash }
      it { expect(assigns(:bike)).to be_decorated }
    end

    describe 'showing example' do
      before do
        ownership = FactoryGirl.create(:ownership)
        ownership.bike.update_attributes(example: true)
        get :show, id: ownership.bike.id
      end
      it { is_expected.to respond_with(:success) }
      it { is_expected.to render_template(:show) }
    end

    describe 'hiding hidden bikes' do
      before do
        ownership = FactoryGirl.create(:ownership)
        ownership.bike.update_attributes(hidden: true)
        get :show, id: ownership.bike.id
      end
      it { is_expected.to set_flash }
      it { is_expected.to redirect_to root_url }
    end

    describe 'showing user-hidden bikes' do
      it 'responds with success' do
        user = FactoryGirl.create(:user)
        ownership = FactoryGirl.create(:ownership, user: user, claimed: true)
        ownership.bike.update_attributes(marked_user_hidden: 'true')
        set_current_user(user)
        get :show, id: ownership.bike_id
        expect(response.code).to eq('200')
      end
    end

    describe 'too large of integer' do
      it 'responds with not found' do
        expect do
          get :show, id: 57549641769762268311552
        end.to raise_error(ActiveRecord::RecordNotFound)
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
      it "does not redirect to new user if a user isn't present" do
        get :new, stolen: true
        expect(response.code).to eq('200')
      end

      it 'renders a new stolen bike' do
        set_current_user(user)
        get :new, { stolen: true }
        expect(response.code).to eq('200')
        expect(assigns(:bike).stolen).to be_truthy
      end

      it 'renders a new recovered bike' do
        set_current_user(user)
        get :new, { recovered: true }
        expect(response.code).to eq('200')
        expect(assigns(:bike).recovered).to be_truthy
      end

      it 'renders a new organization bike' do
        organization = FactoryGirl.create(:organization)
        membership = FactoryGirl.create(:membership, user: user, organization: organization)
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
        allow(controller).to receive(:revised_layout_enabled?) { true }
        set_current_user(user)
      end
      context 'stolen from params' do
        it 'renders a new stolen bike' do
          get :new, stolen: true
          expect(response.code).to eq('200')
          expect(assigns(:bike).stolen).to be_truthy
          b_param = assigns(:b_param)
          expect(b_param.revised_new?).to be_truthy
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
            bike_attrs.each { |k,v| expect(bike.send(k)).to eq(v) }
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
            expect(flash[:notice]).to match(/sorry/i)
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

        it "renders new if b_param isn't owned by user" do
          user = FactoryGirl.create(:user)
          set_current_user(user) 
          post :create, { bike: @bike }
          # expect(response).to render_template('new.html.haml')
          expect(flash[:error]).to eq("Oops, that isn't your bike")
        end

        it 'renders new if there is an error and update the b_params' do
          bike = Bike.new(@bike)
          bike.errors.add(:errory, 'something')
          expect_any_instance_of(BikeCreator).to receive(:create_bike).and_return(bike)
          post :create, { bike: @bike }
          expect(@b_param.reload.bike_errors).not_to be_nil
          expect(response).to render_template('new')
        end
        
        it 'redirects to the created bike if it exists' do
          bike = FactoryGirl.create(:bike)
          @b_param.update_attributes(created_bike_id: bike.id)
          post :create, {bike: {b_param_id_token: @b_param.id_token}}
          expect(response).to redirect_to(edit_bike_url(bike))
        end

        it 'creates a new stolen bike' do
          FactoryGirl.create(:country, iso: 'US')
          @bike[:phone] = '312.379.9513'
          expect do
            post :create, { stolen: 'true', bike: @bike }
          end.to change(StolenRecord, :count).by(1)
          expect(@b_param.reload.created_bike_id).not_to be_nil
          expect(@b_param.reload.bike_errors).to be_nil
          expect(@user.reload.phone).to eq('3123799513')
        end

        it 'creates a new ownership and bike from an organization' do
          organization = FactoryGirl.create(:organization)
          membership = FactoryGirl.create(:membership, user: @user, organization: organization)
          @bike[:creation_organization_id] = organization.id
          expect do
            post :create, { bike: @bike }
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
          b_param = BParam.create(creator_id: organization.auto_user.id, params: {creation_organization_id: organization.id, embeded: true})
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
            post :create, { bike: bike }
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
            b_param = BParam.create(creator_id: organization.auto_user.id, params: {creation_organization_id: organization.id, embeded: true})
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
            post :create, { bike: bike }
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
          b_param = BParam.create(creator_id: organization.auto_user.id, params: {creation_organization_id: organization.id, embeded: true})
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
          }
          post :create, { bike: bike, persist_email: true }
          expect(response).to redirect_to(embed_extended_organization_url(organization, email: 'flow@goodtimes.com'))
        end
      end
    end

    context 'revised' do
      let(:user) { FactoryGirl.create(:user) }
      let(:manufacturer) { FactoryGirl.create(:manufacturer) }
      let(:color) { FactoryGirl.create(:color) }
      before do
        allow(controller).to receive(:revised_layout_enabled?) { true }
        set_current_user(user)
      end
      context 'no existing b_param' do
        it "creates a bike and doesn't create a b_param" do
          bike_params = {
            b_param_id_token: '',
            cycle_type_id: CycleType.bike.id.to_s,
            serial_number: 'example serial',
            manufacturer_id: manufacturer.slug,
            manufacturer_other: '',
            year: '2016',
            frame_model: 'Cool frame model',
            primary_frame_color_id: color.id.to_s,
            secondary_frame_color_id: '',
            tertiary_frame_color_id: '',
            owner_email: 'something@stuff.com'
          }
          expect(BParam.all.count).to eq 0
          expect do
            post :create, bike: bike_params.as_json
          end.to change(Bike, :count).by(1)
          expect(BParam.all.count).to eq 0
          bike = Bike.last
          bike_params.delete(:manufacturer_id)
          bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v }
          expect(bike.manufacturer).to eq manufacturer
        end
      end
      context 'existing b_param' do
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
          expect do
            post :create, bike: { manufacturer_id: manufacturer.slug, b_param_id_token: b_param.id_token }
          end.to change(Bike, :count).by(1)
          bike = Bike.last
          b_param.reload
          expect(b_param.created_bike_id).to eq bike.id
          bike_params.delete(:manufacturer_id)
          bike_params.each { |k, v| expect(bike.send(k).to_s).to eq v }
          expect(bike.manufacturer).to eq manufacturer
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
        expect(flash).to be_present
        expect(flash[:error]).to be_present
      end
    end
    context 'user allowed to edit the bike' do
      let(:user) { ownership.creator }

      context 'legacy' do
        it 'responds with success' do
          set_current_user(user)
          get :edit, id: bike.id
          expect(flash).to_not be_present
          expect(response).to be_success
          expect(assigns(:bike)).to be_decorated
          expect(response).to render_template(:edit)
        end
      end

      context 'revised' do
        before do
          set_current_user(user)
          allow(controller).to receive(:revised_layout_enabled?) { true }
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
        end
        %w(root photos drivetrain accessories ownership stolen).each do |template|
          context template do
            it 'renders the template' do
              get :edit, id: bike.id, page: template
              expect(response).to render_with_layout('application_revised')
              expect(response).to be_success
              expect(response).to render_template("edit_#{template}")
              expect(assigns(:edit_template)).to eq(template)
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
      it { is_expected.to respond_with(:redirect)}
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
    context 'owner present (who is allowed to edit)' do
      let(:user) { FactoryGirl.create(:user) }
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
