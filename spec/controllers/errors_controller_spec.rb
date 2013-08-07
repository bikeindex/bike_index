require 'spec_helper'

describe ErrorsController do

  describe :bad_request do 
    before do 
      get :bad_request
    end
    it { should respond_with(:bad_request) }
    it { should render_template(:bad_request) }
  end

  describe :not_found do 
    before do 
      get :not_found
    end
    it { should respond_with(:not_found) }
    it { should render_template(:not_found) }
  end

  describe :unprocessable_entity do 
    before do 
      get :unprocessable_entity
    end
    it { should respond_with(:unprocessable_entity) }
    it { should render_template(:unprocessable_entity) }
  end

end