require 'spec_helper'

describe BikesController do

  describe :index do 
    before do 
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
    it { should_not set_the_flash }
  end

  describe :show do 
    describe "showing" do 
      before do 
        ownership = FactoryGirl.create(:ownership)
        get :show, id: ownership.bike.id
      end
      it { should respond_with(:success) }
      it { should render_template(:show) }
      it { should_not set_the_flash }
      it { assigns(:bike).should be_decorated }
    end
  end

  describe :spokecard do
    it "should render the page from bike id" do 
      bike = FactoryGirl.create(:bike)
      get :spokecard, id: bike.id
      response.code.should eq('200')
    end
  end

  describe :scanned do 
    it "should render the page from bike id" do 
      bike = FactoryGirl.create(:bike)
      get :scanned, id: bike.id
      response.should redirect_to bike_url(bike)
    end
    it "should redirect to the proper page" do 
      bike = FactoryGirl.create(:bike, card_id: 2)
      get :scanned, card_id: bike.card_id
      response.should redirect_to bike_url(bike)
    end
    it "should render a page if there isn't a connection" do 
      get :scanned, card_id: 12
      response.code.should eq('200')
    end
  end

  describe :new do 
    it "shouldn't redirect to new user if a user isn't present" do 
      get :new, stolen: true
      response.code.should eq('200')
    end

    it "should render a new stolen bike" do 
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:cycle_type, name: "Bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      session[:user_id] = user.id
      get :new, { stolen: true }
      response.code.should eq('200')
    end

    it "should render a new organization bike" do 
      user = FactoryGirl.create(:user)
      organization = FactoryGirl.create(:organization)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      FactoryGirl.create(:cycle_type, name: "Bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      session[:user_id] = user.id
      get :new
      response.code.should eq('200')
    end

    it "should render a new bike_token bike" do 
      user = FactoryGirl.create(:user)
      bike_token = FactoryGirl.create(:bike_token, user: user)
      FactoryGirl.create(:cycle_type, name: "Bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      session[:user_id] = user.id
      get :new, { bike_token_id: bike_token.id }
      response.code.should eq('200')
    end
  end
  

  describe :create do
    before :each do
      @user = FactoryGirl.create(:user)
      @b_param = FactoryGirl.create(:b_param, creator: @user)
      FactoryGirl.create(:cycle_type, name: "Bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      manufacturer = FactoryGirl.create(:manufacturer)
      session[:user_id] = @user.id
      @bike = { serial_number: "1234567890",
        b_param_id: @b_param.id,
        cycle_type_id: FactoryGirl.create(:cycle_type).id,
        manufacturer_id: manufacturer.id,
        rear_tire_narrow: "true",
        rear_wheel_size_id: FactoryGirl.create(:wheel_size).id,
        primary_frame_color_id: FactoryGirl.create(:color).id,
        handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
        owner_email: @user.email
      }
    end

    it "should render new if b_param isn't owned by user" do
      user = FactoryGirl.create(:user)
      session[:user_id] = user.id 
      post :create, { bike: @bike }
      # response.should render_template("new.html.haml")
      flash[:error].should eq("Oops, that isn't your bike")
    end

    it "should render new if there is an error" do
      bike = Bike.new(@bike)
      bike.errors.add(:errory, "something")
      BikeCreator.any_instance.should_receive(:create_bike).and_return(bike)
      post :create, { bike: @bike }
      response.should render_template("new")
    end

    xit "should redirect to charges if payment is required" do
      # DISABLE FOR NOW, we're not accepting any payments.
      post :create, { bike: @bike }
      response.should redirect_to(new_charges_url(b_param_id: @b_param.id))
    end
    
    it "should redirect to the created bike if it exists" do
      bike = FactoryGirl.create(:bike)
      @b_param.update_attributes(created_bike_id: bike.id)
      post :create, {:bike => {b_param_id: @b_param.id}}
      response.should redirect_to(edit_bike_url(bike))
    end

    it "should create a new stolen bike" do
      @bike[:phone] = "312.379.9513"
      lambda {
        post :create, { stolen: "true", bike: @bike}
      }.should change(StolenRecord, :count).by(1)
      @b_param.reload.created_bike_id.should_not be_nil
      @user.reload.phone.should eq("3123799513")
    end

    it "should update the bike token to be used when creating a bike token bike" do
      bike_tokend = FactoryGirl.create(:bike_token, user: @user)
      @bike[:bike_token_id] = bike_tokend.id 
      lambda {
        post :create, {bike: @bike}
      }.should change(Ownership, :count).by(1)
      bike_tokend.reload.used?.should be_true
    end

    it "should create a new ownership and bike from an organization" do
      organization = FactoryGirl.create(:organization)
      membership = FactoryGirl.create(:membership, user: @user, organization: organization)
      @bike[:creation_organization_id] = organization.id
      lambda { 
        post :create, { bike: @bike}
      }.should change(Ownership, :count).by(1)
      Bike.last.creation_organization_id.should eq(organization.id)
    end
  end


  describe :edit do 
    describe "when there is no user" do
      before do 
        ownership = FactoryGirl.create(:ownership)
        get :edit, id: ownership.bike.id
      end
      it { should respond_with(:redirect) }
      it { should redirect_to(bike_url) }
      it { should set_the_flash }
    end
    describe "when a user is present but isn't allowed to edit the bike" do 
      before do 
        ownership = FactoryGirl.create(:ownership)
        user = FactoryGirl.create(:user)
        session[:user_id] = user.id
        get :edit, id: ownership.bike.id
      end
      it { should respond_with(:redirect)}
      it { should redirect_to(bike_url) }
      it { should set_the_flash }
    end
    describe "when a user is present who is allowed to edit the bike" do 
      before do 
        ownership = FactoryGirl.create(:ownership)
        user = ownership.creator
        session[:user_id] = user.id
        get :edit, id: ownership.bike.id
      end
      it { should respond_with(:success)}
      it { should render_template(:edit) }
      it { should_not set_the_flash }   
      it { assigns(:bike).should be_decorated }
    end
  end

  describe :update do 
    describe "when a user is present but isn't allowed to update the bike" do 
      before do 
        ownership = FactoryGirl.create(:ownership)
        user = FactoryGirl.create(:user)
        session[:user_id] = user.id
        put :update, {id: ownership.bike.id, :bike => {serial_number: "69"}}
      end
      it { should respond_with(:redirect)}
      it { should redirect_to(bike_url) }
      it { should set_the_flash }
    end
    it "should update the bike when a user is present who is allowed to edit the bike" do 
      ownership = FactoryGirl.create(:ownership)
      user = ownership.creator
      session[:user_id] = user.id
      put :update, {id: ownership.bike.id, :bike => {description: "69"}}
      ownership.bike.reload.description.should eq("69")
      assigns(:bike).should be_decorated
    end

    it "should create a new ownership if the email changes" do 
      ownership = FactoryGirl.create(:ownership)
      user = ownership.creator
      session[:user_id] = user.id
      lambda { put :update,
        {id: ownership.bike.id, :bike => {owner_email: "new@email.com"}}
      }.should change(Ownership, :count).by(1)
    end
  end

end