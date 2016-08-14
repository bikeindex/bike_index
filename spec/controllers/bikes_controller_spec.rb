require 'spec_helper'

describe BikesController do
  it_behaves_like 'bikes_controller_create' # Splitting spec file up, it's too big
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
          context 'proximity of "ip"' do
            it 'renders, assigns location via geocoder' do
              # Without a matching current stolen record, it doesn't go whole way through proximity
              FactoryGirl.create(:stolen_bike)
              get :index, proximity: 'ip', stolen: true
              expect(response.status).to eq(200)
              expect(flash).to_not be_present
              expect(assigns(:per_page)).to eq 10
              target_location = [{ data: default_location, cache_hit: nil }].as_json # in spec_helper
              expect(assigns(:location).as_json).to eq target_location
              expect(assigns(:stolenness)).to eq 'stolen_proximity'
              expect(response).to render_with_layout('application_revised')
            end
          end
          context 'proximity of "you"' do
            it 'renders, assigns location via geocoder' do
              # Without a matching current stolen record, it doesn't go whole way through proximity
              FactoryGirl.create(:stolen_bike)
              get :index, proximity: 'you', stolen: true
              expect(response.status).to eq(200)
              expect(flash).to_not be_present
              expect(assigns(:per_page)).to eq 10
              target_location = [{ data: default_location, cache_hit: nil }].as_json # in spec_helper
              expect(assigns(:location).as_json).to eq target_location
              expect(assigns(:stolenness)).to eq 'stolen_proximity'
              expect(response).to render_with_layout('application_revised')
            end
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
          it 'renders for the user (even though a different creator)' do
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
          ownership.bike.update_attributes(example: true)
          put :update, id: bike.id, bike: { description: '69' }
          expect(response).to redirect_to edit_bike_url(bike)
          bike.reload
          expect(bike.description).to eq('69')
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
          it 'updates and returns to the right page' do
            state = FactoryGirl.create(:state)
            country = state.country
            stolen_record = FactoryGirl.create(:stolen_record, bike: bike, city: 'party')
            bike.stolen = true
            # bike.marked_user_hidden = true
            bike.save
            expect(stolen_record.date_stolen).to be_present
            expect(stolen_record.proof_of_ownership).to be_falsey
            expect(stolen_record.receive_notifications).to be_truthy
            bike.reload
            # bike.update_attributes(stolen: true, current_stolen_record_id: stolen_record.id)
            bike.reload
            expect(bike.find_current_stolen_record).to eq stolen_record
            stolen_attrs = {
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
            bike_attrs = {
              stolen: true,
              stolen_records_attributes: {
                '0' => stolen_attrs
              }
            }
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
            skipped_attrs = %w(proof_of_ownership receive_notifications date_stolen_input).map(&:to_sym)
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
