require 'spec_helper'

describe ManufacturersController do
  describe 'index' do
    before do
      get :index
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:index) }
  end

  describe 'tsv' do
    before do
      get :tsv
    end
    it { is_expected.to respond_with(:redirect) }
  end
end
