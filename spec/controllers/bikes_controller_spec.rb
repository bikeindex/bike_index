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

    describe "showing example" do 
      before do 
        ownership = FactoryGirl.create(:ownership)
        ownership.bike.update_attributes(example: true)
        get :show, id: ownership.bike.id
      end
      it { should respond_with(:success) }
      it { should render_template(:show) }
    end

    describe "hiding hidden bikes" do 
      before do 
        ownership = FactoryGirl.create(:ownership)
        ownership.bike.update_attributes(hidden: true)
        get :show, id: ownership.bike.id
      end
      it { should set_the_flash }
      it { should redirect_to root_url }
    end

    describe "showing user-hidden bikes" do
      it "responds with success" do 
        user = FactoryGirl.create(:user)
        ownership = FactoryGirl.create(:ownership, user: user, claimed: true)
        ownership.bike.update_attributes(marked_user_hidden: 'true')
        set_current_user(user)
        get :show, id: ownership.bike_id
        response.code.should eq('200')
      end
    end
  end

  describe :spokecard do
    it "renders the page from bike id" do 
      bike = FactoryGirl.create(:bike)
      get :spokecard, id: bike.id
      response.code.should eq('200')
    end
  end

  describe :scanned do 
    it "renders the page from bike id" do 
      bike = FactoryGirl.create(:bike)
      get :scanned, id: bike.id
      response.should redirect_to bike_url(bike)
    end
    it "redirects to the proper page" do 
      bike = FactoryGirl.create(:bike, card_id: 2)
      get :scanned, card_id: bike.card_id
      response.should redirect_to bike_url(bike)
    end
    it "renders a page if there isn't a connection" do 
      get :scanned, card_id: 12
      response.code.should eq('200')
    end
  end

  describe :new do 
    it "does not redirect to new user if a user isn't present" do 
      get :new, stolen: true
      response.code.should eq('200')
    end

    it "renders a new stolen bike" do 
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      set_current_user(user)
      get :new, { stolen: true }
      response.code.should eq('200')
      assigns(:bike).stolen.should be_true
    end

    it "renders a new recovered bike" do 
      user = FactoryGirl.create(:user)
      FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      set_current_user(user)
      get :new, { recovered: true }
      response.code.should eq('200')
      assigns(:bike).recovered.should be_true
    end

    it "renders a new organization bike" do 
      user = FactoryGirl.create(:user)
      organization = FactoryGirl.create(:organization)
      membership = FactoryGirl.create(:membership, user: user, organization: organization)
      FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      set_current_user(user)
      get :new
      response.code.should eq('200')
    end

    it "renders a new bike_token bike" do 
      user = FactoryGirl.create(:user)
      bike_token = FactoryGirl.create(:bike_token, user: user)
      FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
      FactoryGirl.create(:propulsion_type, name: "Foot pedal")
      set_current_user(user)
      get :new, { bike_token_id: bike_token.id }
      response.code.should eq('200')
    end
  end
  

  describe :create do
    describe "web interface submission" do 
      before :each do
        @user = FactoryGirl.create(:user)
        @b_param = FactoryGirl.create(:b_param, creator: @user)
        FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
        FactoryGirl.create(:propulsion_type, name: "Foot pedal")
        manufacturer = FactoryGirl.create(:manufacturer)
        set_current_user(@user)
        @bike = { serial_number: "1234567890",
          b_param_id_token: @b_param.id_token,
          cycle_type_id: FactoryGirl.create(:cycle_type).id,
          manufacturer_id: manufacturer.id,
          rear_tire_narrow: "true",
          rear_wheel_size_id: FactoryGirl.create(:wheel_size).id,
          primary_frame_color_id: FactoryGirl.create(:color).id,
          handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
          owner_email: @user.email
        }
      end

      it "renders new if b_param isn't owned by user" do
        user = FactoryGirl.create(:user)
        set_current_user(user) 
        post :create, { bike: @bike }
        # response.should render_template("new.html.haml")
        flash[:error].should eq("Oops, that isn't your bike")
      end

      it "renders new if there is an error and update the b_params" do
        bike = Bike.new(@bike)
        bike.errors.add(:errory, "something")
        BikeCreator.any_instance.should_receive(:create_bike).and_return(bike)
        post :create, { bike: @bike }
        @b_param.reload.bike_errors.should_not be_nil
        response.should render_template("new")
      end
      
      it "redirects to the created bike if it exists" do
        bike = FactoryGirl.create(:bike)
        @b_param.update_attributes(created_bike_id: bike.id)
        post :create, {bike: {b_param_id_token: @b_param.id_token}}
        response.should redirect_to(edit_bike_url(bike))
      end

      it "creates a new stolen bike" do
        FactoryGirl.create(:country, iso: "US")
        @bike[:phone] = "312.379.9513"
        lambda {
          post :create, { stolen: "true", bike: @bike}
        }.should change(StolenRecord, :count).by(1)
        @b_param.reload.created_bike_id.should_not be_nil
        @b_param.reload.bike_errors.should be_nil
        @user.reload.phone.should eq("3123799513")
      end

      it "updates the bike token to be used when creating a bike token bike" do
        bike_tokend = FactoryGirl.create(:bike_token, user: @user)
        @bike[:bike_token_id] = bike_tokend.id 
        lambda {
          post :create, {bike: @bike}
        }.should change(Ownership, :count).by(1)
        bike_tokend.reload.used?.should be_true
      end

      it "creates a new ownership and bike from an organization" do
        organization = FactoryGirl.create(:organization)
        membership = FactoryGirl.create(:membership, user: @user, organization: organization)
        @bike[:creation_organization_id] = organization.id
        lambda { 
          post :create, { bike: @bike}
        }.should change(Ownership, :count).by(1)
        Bike.last.creation_organization_id.should eq(organization.id)
      end
    end
    
    describe "embeded submission" do 
      it "creates a new ownership and bike from an organization" do
        organization = FactoryGirl.create(:organization)
        user = FactoryGirl.create(:user)
        FactoryGirl.create(:membership, user: user, organization: organization)
        organization.save
        FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
        FactoryGirl.create(:propulsion_type, name: "Foot pedal")
        manufacturer = FactoryGirl.create(:manufacturer)
        b_param = BParam.create(creator_id: organization.auto_user.id, params: {creation_organization_id: organization.id, embeded: true})
        bike = { serial_number: "69",
          b_param_id_token: b_param.id_token,
          creation_organization_id: organization.id,
          embeded: true,
          cycle_type_id: FactoryGirl.create(:cycle_type).id,
          manufacturer_id: manufacturer.id,
          primary_frame_color_id: FactoryGirl.create(:color).id,
          handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
          owner_email: "Flow@goodtimes.com"
        }
        lambda { 
          post :create, { bike: bike}
        }.should change(Ownership, :count).by(1)
        Bike.last.creation_organization_id.should eq(organization.id)
      end
    end

    describe "extended embeded submission" do 
      it "registers a bike and upload an image" do 
        Sidekiq::Testing.inline! do 
          organization = FactoryGirl.create(:organization)
          user = FactoryGirl.create(:user)
          FactoryGirl.create(:membership, user: user, organization: organization)
          organization.save
          FactoryGirl.create(:cycle_type, name: "Bike", slug: "bike")
          FactoryGirl.create(:propulsion_type, name: "Foot pedal")
          manufacturer = FactoryGirl.create(:manufacturer)
          b_param = BParam.create(creator_id: organization.auto_user.id, params: {creation_organization_id: organization.id, embeded: true})
          test_photo = Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, 'spec', 'fixtures', 'bike.jpg')))
          ImageAssociatorWorker.any_instance.should_receive(:perform).and_return(true)
          bike = { serial_number: "69",
            b_param_id_token: b_param.id_token,
            creation_organization_id: organization.id,
            embeded: true,
            embeded_extended: true,
            cycle_type_id: FactoryGirl.create(:cycle_type).id,
            manufacturer_id: manufacturer.id,
            primary_frame_color_id: FactoryGirl.create(:color).id,
            handlebar_type_id: FactoryGirl.create(:handlebar_type).id,
            owner_email: "Flow@goodtimes.com",
            image: test_photo
          }
          post :create, { bike: bike}
        end
      end
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
        set_current_user(user)
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
        set_current_user(user)
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
        set_current_user(user)
        put :update, {id: ownership.bike.id, bike: {serial_number: "69"}}
      end
      it { should respond_with(:redirect)}
      it { should redirect_to(bike_url) }
      it { should set_the_flash }
    end

    it "allows you to edit an example bike" do 
      ownership = FactoryGirl.create(:ownership)
      ownership.bike.update_attributes(example: true)
      user = ownership.creator
      set_current_user(user)
      put :update, {id: ownership.bike.id, bike: {description: "69"}}
      ownership.bike.reload.description.should eq("69")
      response.should redirect_to bike_url(ownership.bike)
    end

    it "updates the bike when a user is present who is allowed to edit the bike" do 
      ownership = FactoryGirl.create(:ownership)
      user = ownership.creator
      set_current_user(user)
      put :update, {id: ownership.bike.id, bike: {description: "69", marked_user_hidden: "0"}}
      ownership.bike.reload.description.should eq("69")
      response.should redirect_to bike_url(ownership.bike)
      assigns(:bike).should be_decorated
      ownership.bike.hidden.should be_false
    end

    it "marks the bike unhidden" do 
      ownership = FactoryGirl.create(:ownership)
      ownership.bike.update_attribute :marked_user_hidden, '1'
      ownership.bike.reload.hidden.should be_true
      user = ownership.creator
      set_current_user(user)
      put :update, {id: ownership.bike.id, bike: {marked_user_unhidden: "true"}}
      ownership.bike.reload.hidden.should be_false
    end

    it "creates a new ownership if the email changes" do 
      ownership = FactoryGirl.create(:ownership)
      user = ownership.creator
      set_current_user(user)
      lambda { put :update,
        {id: ownership.bike.id, bike: {owner_email: "new@email.com"}}
      }.should change(Ownership, :count).by(1)
    end

    it "redirects to return_to if it's a valid url" do
      ownership = FactoryGirl.create(:ownership)
      user = ownership.creator
      set_current_user(user)
      session[:return_to] = '/about'
      put :update, {id: ownership.bike.id, bike: {description: "69", marked_user_hidden: "0"}}
      ownership.bike.reload.description.should eq("69")
      response.should redirect_to "/about"
      session[:return_to].should be_nil
    end

    it "doesn't redirect and clears the session if not a valid url" do
      ownership = FactoryGirl.create(:ownership)
      user = ownership.creator
      set_current_user(user)
      session[:return_to] = 'http://testhost.com/bad_place'
      put :update, {id: ownership.bike.id, bike: {description: "69", marked_user_hidden: "0"}}
      ownership.bike.reload.description.should eq("69")
      session[:return_to].should be_nil
      response.should redirect_to bike_url
    end
  end

end
