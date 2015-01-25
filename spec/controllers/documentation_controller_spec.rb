require 'spec_helper'

describe DocumentationController do

  describe :index do 
    before do 
      get :index
    end
    it { should respond_with(:redirect) }
    it { should redirect_to('/documentation/api_v2') }
  end

  describe :api_v1 do 
    before do 
      get :api_v1
    end
    it { should respond_with(:success) }
    it { should render_template(:api_v1) }
  end

  describe :api_v2 do 
    before do 
      get :api_v2
    end
    it { should respond_with(:success) }
    it { should render_template(:api_v2) }
  end
end
