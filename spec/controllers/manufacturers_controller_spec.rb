require 'spec_helper'

describe ManufacturersController do

  describe :index do 
    before do 
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
  end

  describe :show do 
    before do 
      mnfg = FactoryGirl.create(:manufacturer)
      get :show, id: mnfg.slug
    end
    it { should respond_with(:success) }
    it { should render_template(:show) }
  end

  describe :mock_csv do 
    before do 
      get :mock_csv
    end
    it { should respond_with(:success) }
    it { should render_template(:mock_csv) }
  end

end
