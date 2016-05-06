require 'spec_helper'

describe ManufacturersController do
  describe 'index' do
    it 'renders with revised_layout' do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(response).to render_with_layout('application_revised')
    end
  end
  describe 'tsv' do
    before do
      get :tsv
    end
    it { is_expected.to respond_with(:redirect) }
  end
end
