require 'spec_helper'

describe Admin::GraphsController, type: :controller do
  include_context :logged_in_as_super_admin
  describe 'index' do
    context 'graphs' do
      it 'renders' do
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
    context 'tables' do
      it 'redirects to tables' do
        get :index, tables: true
        expect(response).to redirect_to(:tables_admin_graphs)
      end
    end
  end

  describe 'tables' do
    it 'renders' do
      get :tables
      expect(response.status).to eq(200)
      expect(response).to render_template(:tables)
    end
  end

  describe 'users' do
    it 'returns json' do
      get :users
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result.keys.count).to be > 0
    end
  end

  describe 'bikes' do
    context 'no params' do
      it 'returns JSON array' do
        get :bikes
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result.is_a?(Array)).to be_truthy
        names = result.map { |r| r['name'] }
        expect(names.include?('Registrations')).to be_truthy
        expect(names.include?('Stolen')).to be_truthy
      end
    end
    context 'start_at passed' do
      it 'returns JSON array' do
        get :bikes, start_at: 'past_year'
        expect(response.status).to eq(200)
        result = JSON.parse(response.body)
        expect(result.is_a?(Array)).to be_truthy
        names = result.map { |r| r['name'] }
        expect(names.include?('Registrations')).to be_truthy
        expect(names.include?('Stolen')).to be_truthy
      end
    end
  end
end
