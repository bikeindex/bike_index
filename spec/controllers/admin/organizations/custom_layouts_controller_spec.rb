require 'spec_helper'

describe Admin::Organizations::CustomLayoutsController, type: :controller do
  let(:organization) { FactoryGirl.create(:organization) }
  context 'super admin' do
    include_context :logged_in_as_super_admin

    describe 'index' do
      it 'redirects' do
        get :index, organization_id: organization.to_param
        expect(response).to redirect_to(admin_organization_url(organization))
        expect(flash).to be_present
      end
    end
  end

  context 'super admin and developer' do
    let(:user) { FactoryGirl.create(:admin, developer: true) }
    before do
      set_current_user(user)
    end

    describe 'index' do
      it 'renders' do
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end

    describe 'edit' do
      context 'landing_page' do
        it 'renders' do
          get :edit, organization_id: organization.to_param, id: 'landing_page'
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit_landing_page)
        end
      end
      context 'mail_snippets' do
        it 'renders' do
          get :edit, organization_id: organization.to_param, id: 'mail_snippets'
          expect(response.status).to eq(200)
          expect(response).to render_template(:edit_mail_snippets)
        end
      end
    end

    # describe 'organization update' do
    #   let(:state) { FactoryGirl.create(:state) }
    #   let(:country) { state.country }
    #   let(:location_1) { FactoryGirl.create(:location, organization: organization, street: 'old street', name: 'cool name') }
    #   let(:update_attributes) do
    #     {
    #       name: 'new name thing stuff',
    #       landing_html: '<p>html</p>',
    #       show_on_map: true,
    #       org_type: 'shop',
    #       locations_attributes: {
    #         '0' => {
    #           id: location_1.id,
    #           name: 'First shop',
    #           zipcode: '2222222',
    #           city: 'First city',
    #           state_id: state.id,
    #           country_id: country.id,
    #           street: 'some street 2',
    #           phone: '7272772727272',
    #           email: 'stuff@goooo.com',
    #           latitude: 22_222,
    #           longitude: 11_111,
    #           organization_id: 844,
    #           shown: false,
    #           _destroy: 0
    #         },
    #         Time.zone.now.to_i.to_s => {
    #           created_at: Time.zone.now.to_f.to_s,
    #           name: 'Second shop',
    #           zipcode: '12243444',
    #           city: 'cool city',
    #           state_id: state.id,
    #           country_id: country.id,
    #           street: 'some street 2',
    #           phone: '7272772727272',
    #           email: 'stuff@goooo.com',
    #           latitude: 22_222,
    #           longitude: 11_111,
    #           organization_id: 844,
    #           shown: false
    #         }
    #       }
    #     }
    #   end
    #   it 'updates the organization' do
    #     expect(location_1).to be_present
    #     expect do
    #       put :update, organization_id: organization.to_param, id: organization.to_param, organization: update_attributes
    #     end.to change(Location, :count).by 1
    #     organization.reload
    #     expect(organization.name).to eq update_attributes[:name]
    #     expect(organization.landing_html).to eq update_attributes[:landing_html]
    #     # Existing location is updated
    #     location_1.reload
    #     expect(location_1.organization).to eq organization
    #     update_attributes[:locations_attributes]['0'].except(:latitude, :longitude, :organization_id, :created_at, :_destroy).each do |k, v|
    #       expect(location_1.send(k)).to eq v
    #     end
    #     # still existing location
    #     location_2 = organization.locations.last
    #     key = update_attributes[:locations_attributes].keys.last
    #     update_attributes[:locations_attributes][key].except(:latitude, :longitude, :organization_id, :created_at).each do |k, v|
    #       expect(location_2.send(k)).to eq v
    #     end
    #   end
    # end
  end
end
