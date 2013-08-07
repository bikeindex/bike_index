require 'spec_helper'

describe InfoController do

  describe :about do 
    before do 
      get :about
    end
    it { should respond_with(:success) }
    it { should render_template(:about) }
  end

  describe :about do 
    before do 
      get :about
    end
    it { should respond_with(:success) }
    it { should render_template(:about)}
  end

  describe :stolen do 
    before do 
      get :stolen
    end
    it { should respond_with(:success) }
    it { should render_template(:stolen)}
  end

  describe :where do 
    before do 
      get :where
    end
    it { should respond_with(:success) }
    it { should render_template(:where)}
  end

  describe :roadmap do 
    before do 
      get :roadmap
    end
    it { should respond_with(:success) }
    it { should render_template(:roadmap)}
  end

  describe :security do 
    before do 
      get :security
    end
    it { should respond_with(:success) }
    it { should render_template(:security)}
  end

  describe :serials do 
    before do 
      get :serials
    end
    it { should respond_with(:success) }
    it { should render_template(:serials)}
  end

  describe :stolen_bikes do 
    before do 
      get :stolen_bikes
    end
    it { should respond_with(:success) }
    it { should render_template(:stolen_bikes)}
  end

  describe :privacy do 
    before do 
      get :privacy
    end
    it { should respond_with(:success) }
    it { should render_template(:privacy)}
  end

  describe :terms do 
    before do 
      get :terms
    end
    it { should respond_with(:success) }
    it { should render_template(:terms)}
  end

  describe :vendor_terms do 
    before do 
      get :vendor_terms
    end
    it { should respond_with(:success) }
    it { should render_template(:vendor_terms)}
  end

  describe :resources do 
    before do 
      get :resources
    end
    it { should respond_with(:success) }
    it { should render_template(:resources)}
  end

  describe :spokecard do 
    before do 
      get :spokecard
    end
    it { should respond_with(:success) }
    it { should render_template(:spokecard)}
  end

  describe :set_title do
    it "should set the title based on the current action" do 
      controller.should_receive(:action_name).and_return("about bikey things")
      controller.set_title.should eq("About Bikey Things")
    end
  end
  

end