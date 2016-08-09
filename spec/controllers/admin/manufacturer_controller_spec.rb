require 'spec_helper'

describe Admin::ManufacturersController, type: :controller do
  let(:subject) { FactoryGirl.create(:manufacturer) }
  include_context :logged_in_as_super_admin

  let(:permitted_attributes) do
    {
      name: 'new name',
      slug: 'new_name',
      website: 'http://stuff.com',
      frame_maker: true,
      open_year: 1992,
      close_year: 89898,
      description: 'new description'
    }
  end

  describe 'index' do
    it 'renders' do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe 'show' do
    it 'renders' do
      get :show, id: subject.slug
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
  end

  describe 'edit' do
    context 'slug' do
      it 'renders' do
        get :edit, id: subject.slug
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end
    context 'id' do
      it 'renders' do
        get :edit, id: subject.id
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'update' do
    it 'updates available attributes' do
      put :update, id: subject.to_param, manufacturer: permitted_attributes
      subject.reload
      permitted_attributes.each { |attribute, val| expect(subject.send(attribute)).to eq val }
    end
  end

  describe 'create' do
    it 'creates with available attributes' do
      expect do
        post :create, manufacturer: permitted_attributes
      end.to change(Manufacturer, :count).by 1
      target = Manufacturer.last
      permitted_attributes.each { |attribute, val| expect(target.send(attribute)).to eq val }
    end
  end
end
