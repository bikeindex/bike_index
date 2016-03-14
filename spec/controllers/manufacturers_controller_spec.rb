require 'spec_helper'

describe ManufacturersController do

  describe :index do 
    before do 
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
  end

  describe :tsv do 
    before do 
      get :tsv
    end
    it { should respond_with(:redirect) }
  end

end
