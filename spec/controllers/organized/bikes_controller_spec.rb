require 'spec_helper'

describe Organized::BikesController, type: :controller do
  let(:non_organization_bike) { FactoryGirl.create(:bike) }
  before do
    expect(non_organization_bike).to be_present
  end
  context 'logged_in_as_organization_admin' do
    include_context :logged_in_as_organization_admin
    describe 'index' do
      it 'renders' do
        get :index, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :index
        expect(response).to render_with_layout('application_revised')
        expect(assigns(:current_organization)).to eq organization
        expect(assigns(:page_id)).to eq 'organized_bikes_index'
      end
    end

    describe 'new' do
      it 'renders' do
        get :new, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :new
        expect(response).to render_with_layout('application_revised')
        expect(assigns(:current_organization)).to eq organization
      end
    end
  end

  context 'logged_in_as_organization_member' do
    include_context :logged_in_as_organization_member
    describe 'index' do
      context 'paid organization' do
        before do
          organization.update_attribute :is_paid, true
          expect(organization.is_paid).to be_truthy
        end
        context 'with params' do
          let(:query_params) do
            {
              query: '1',
              manufacturer: '2',
              colors: %w(3 4),
              location: '5',
              distance: '6',
              serial: '9',
              query_items: %w(7 8),
              stolenness: 'stolen'
            }.as_json
          end
          let(:organization_bikes) { organization.bikes }
          it 'sends all the params and renders search template to organization_bikes' do
            expect_any_instance_of(Organized::BikesController).to receive(:forwarded_ip_address) { 'special' }
            allow_any_instance_of(Organized::BikesController).to receive(:organization_bikes) { organization_bikes }
            expect(Bike).to receive(:searchable_interpreted_params).with(query_params, ip: 'special') { { search_params: '' } }
            expect(organization_bikes).to receive(:search).with(search_params: '') { organization_bikes }
            get :index, query_params.merge(organization_id: organization.to_param)
            expect(response.status).to eq(200)
            expect(response).to render_template :search
            expect(assigns(:current_organization)).to eq organization
            expect(assigns(:search_query_present)).to be_truthy
            expect(assigns(:bikes).pluck(:id).include?(non_organization_bike.id)).to be_falsey
          end
        end
        context 'without params' do
          it 'renders, assigns search_query_present and stolenness all' do
            get :index, organization_id: organization.to_param
            expect(response.status).to eq(200)
            expect(response).to render_template :search
            expect(assigns(:interpreted_params)[:stolenness]).to eq 'all'
            expect(assigns(:current_organization)).to eq organization
            expect(assigns(:search_query_present)).to be_falsey
            expect(assigns(:bikes).pluck(:id).include?(non_organization_bike.id)).to be_falsey
          end
        end
      end
      context 'unpaid organization' do
        before do
          expect(organization.is_paid).to be_falsey
        end
        it 'renders without search' do
          expect(Bike).to_not receive(:search)
          get :index, organization_id: organization.to_param
          expect(response.status).to eq(200)
          expect(response).to render_template :index
          expect(response).to render_with_layout('application_revised')
          expect(assigns(:current_organization)).to eq organization
          expect(assigns(:bikes).pluck(:id).include?(non_organization_bike.id)).to be_falsey
        end
      end
    end

    describe 'new' do
      it 'renders' do
        get :new, organization_id: organization.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template :new
        expect(response).to render_with_layout('application_revised')
        expect(assigns(:current_organization)).to eq organization
      end
    end
  end
end
