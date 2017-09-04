require 'spec_helper'

describe Admin::OrganizationsController, type: :controller do
  let(:organization) { FactoryGirl.create(:organization, approved: false) }
  include_context :logged_in_as_super_admin

  describe 'index' do
    it 'renders' do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe 'edit' do
    it 'renders' do
      get :edit, id: organization.to_param
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe 'organization update' do
    let(:state) { FactoryGirl.create(:state) }
    let(:country) { state.country }
    let(:location_1) { FactoryGirl.create(:location, organization: organization, street: 'old street', name: 'cool name') }
    let(:update_attributes) do
      {
        name: 'new name thing stuff',
        show_on_map: true,
        org_type: 'shop',
        is_paid: 'true',
        locations_attributes: {
          '0' => {
            id: location_1.id,
            name: 'First shop',
            zipcode: '2222222',
            city: 'First city',
            state_id: state.id,
            country_id: country.id,
            street: 'some street 2',
            phone: '7272772727272',
            email: 'stuff@goooo.com',
            latitude: 22_222,
            longitude: 11_111,
            organization_id: 844,
            shown: false,
            _destroy: 0
          },
          Time.zone.now.to_i.to_s => {
            created_at: Time.zone.now.to_f.to_s,
            name: 'Second shop',
            zipcode: '12243444',
            city: 'cool city',
            state_id: state.id,
            country_id: country.id,
            street: 'some street 2',
            phone: '7272772727272',
            email: 'stuff@goooo.com',
            latitude: 22_222,
            longitude: 11_111,
            organization_id: 844,
            shown: false
          }
        }
      }
    end
    it 'updates the organization' do
      expect(location_1).to be_present
      expect do
        put :update, organization_id: organization.to_param, id: organization.to_param, organization: update_attributes
      end.to change(Location, :count).by 1
      organization.reload
      expect(organization.name).to eq update_attributes[:name]
      expect(organization.is_paid).to be_truthy
      # Existing location is updated
      location_1.reload
      expect(location_1.organization).to eq organization
      update_attributes[:locations_attributes]['0'].except(:latitude, :longitude, :organization_id, :created_at, :_destroy).each do |k, v|
        expect(location_1.send(k)).to eq v
      end
      # still existing location
      location_2 = organization.locations.last
      key = update_attributes[:locations_attributes].keys.last
      update_attributes[:locations_attributes][key].except(:latitude, :longitude, :organization_id, :created_at).each do |k, v|
        expect(location_2.send(k)).to eq v
      end
    end
  end
end
