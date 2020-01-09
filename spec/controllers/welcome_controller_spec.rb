require "rails_helper"

RSpec.describe WelcomeController, type: :controller do
  describe "index" do
    it "renders" do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template("index")
      expect(flash).to_not be_present
    end
    context "json request format" do
      it "renders revised_layout (ignoring response format)" do
        get :index, format: :json
        expect(response.status).to eq(200)
        expect(response).to render_template("index")
        expect(flash).to_not be_present
      end
    end
    context "organization deleted" do
      include_context :logged_in_as_organization_admin
      it "renders" do
        org_id = organization.id
        session[:passive_organization_id] = org_id
        expect(user.default_organization).to be_present
        organization.destroy
        user.reload
        expect(Organization.unscoped.find(org_id)).to be_present
        expect(user.organizations.count).to eq 0
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end
    end
  end

  describe "bike_creation_graph" do
    it "renders embed without xframe block" do
      get :bike_creation_graph
      expect(response.code).to eq("200")
      expect(response.headers["X-Frame-Options"]).not_to be_present
    end
  end

  describe "goodbye" do
    it "renders" do
      get :goodbye
      expect(response.status).to eq(200)
      expect(response).to render_template("goodbye")
      expect(flash).to_not be_present
    end
    context "logged_in" do
      include_context :logged_in_as_user
      it "redirects" do
        get :goodbye
        expect(response).to redirect_to logout_url
      end
      context "unconfirmed user" do
        let(:user) { FactoryBot.create(:user) }
        it "redirects" do
          get :goodbye
          expect(response).to redirect_to logout_url
        end
      end
    end
  end

  describe "choose registration" do
    context "user not present" do
      it "redirects" do
        get :choose_registration
        expect(response).to redirect_to(new_user_url)
      end
    end
    context "user present" do
      it "renders" do
        user = FactoryBot.create(:user_confirmed)
        set_current_user(user)
        get :choose_registration
        expect(response.status).to eq(200)
        expect(response).to render_template("choose_registration")
      end
    end
  end

  describe "user_home" do
    context "user not logged in" do
      it "redirects" do
        get :user_home
        expect(response).to redirect_to(new_user_url)
      end
    end

    context "user logged in" do
      before { set_current_user(user) }

      context "unconfirmed" do
        let(:user) { FactoryBot.create(:user) }
        it "redirects" do
          get :user_home
          expect(flash).to_not be_present
          expect(response).to redirect_to(please_confirm_email_users_path)
        end
      end

      context "confirmed" do
        let(:user) { FactoryBot.create(:user_confirmed) }
        context "without anything" do
          it "renders" do
            get :user_home
            expect(response.status).to eq(200)
            expect(response).to render_template("user_home")
            expect(session[:passive_organization_id]).to eq "0"
            expect(assigns[:passive_organization]).to be_nil
          end
        end
        context "with organization" do
          let(:organization) { FactoryBot.create(:organization) }
          let(:user) { FactoryBot.create(:organization_member, organization: organization) }
          it "sets passive_organization_id" do
            get :user_home
            expect(response.status).to eq(200)
            expect(response).to render_template("user_home")
            expect(session[:passive_organization_id]).to eq organization.id
            expect(assigns[:passive_organization]).to eq organization
          end
        end
        context "with stuff" do
          let(:ownership) { FactoryBot.create(:ownership, user_id: user.id, current: true) }
          let(:bike) { ownership.bike }
          let(:bike_2) { FactoryBot.create(:bike) }
          let(:lock) { FactoryBot.create(:lock, user: user) }
          let(:organization) { FactoryBot.create(:organization) }
          before do
            allow_any_instance_of(User).to receive(:bikes) { [bike, bike_2] }
            allow_any_instance_of(User).to receive(:locks) { [lock] }
          end
          it "renders and user things are assigned" do
            session[:passive_organization_id] = organization.id # Even though the user isn't part of the organization, permit it
            get :user_home, per_page: 1
            expect(response.status).to eq(200)
            expect(response).to render_template("user_home")
            expect(assigns(:bikes).count).to eq 1
            expect(assigns(:per_page).to_s).to eq "1"
            expect(assigns(:bikes).first).to eq(bike)
            expect(assigns(:locks).first).to eq(lock)
            expect(session[:passive_organization_id]).to eq organization.id
            expect(assigns[:passive_organization]).to eq organization
          end
        end
        context "with show_missing_location_alert" do
          let(:ownership) { FactoryBot.create(:ownership_claimed, creator: user, user: user) }
          let(:bike) { ownership.bike }
          let!(:stolen_record) { FactoryBot.create(:stolen_record, bike: bike, street: "") }
          it "renders with show_missing_location_alert" do
            bike.reload
            bike.update_attributes(stolen: true, updated_at: Time.current)
            # Unmemoize stolen missing locations
            user_id = user.id
            user = User.find user_id
            user.update_attributes(updated_at: Time.current)
            expect(user.has_stolen_bikes_without_locations).to be_truthy
            expect(bike.stolen).to be_truthy
            expect(bike.current_stolen_record).to eq stolen_record
            expect(bike.current_stolen_record.missing_location?).to be_truthy
            get :user_home

            expect(response).to be_success
            expect(assigns(:show_missing_location_alert?)).to be_falsey
            expect(response).to render_template("user_home")
          end
        end
      end
    end

    describe "recovery_stories" do
      it "renders recovery stories" do
        FactoryBot.create_list(:recovery_display, 3)
        get :recovery_stories, per_page: 2
        expect(assigns(:recovery_displays).count).to eq 2
        expect(response.status).to eq(200)
        expect(response).to render_template("recovery_stories")
        expect(flash).to_not be_present
      end

      it "renders no recovery stories if requested page exceeds valid range" do
        FactoryBot.create_list(:recovery_display, 2)
        get :recovery_stories, per_page: 2, page: 2
        expect(assigns(:recovery_displays)).to be_empty
        expect(response.status).to eq(200)
        expect(response).to render_template("recovery_stories")
        expect(flash).to be_present
      end
    end
  end
end
