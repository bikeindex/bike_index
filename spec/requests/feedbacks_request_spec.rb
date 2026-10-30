require "rails_helper"

base_url = "/feedbacks"
RSpec.describe FeedbacksController, type: :request do
  describe "index" do
    it "renders with revised_layout" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end

    context "logged in" do
      include_context :request_spec_logged_in_as_user

      it "renders the detail prompt and the message template" do
        get base_url
        expect(response.body).to match(/The more detail you can share/)
        expect(response.body).to match(/Bike serial number \(if applicable\):/)
      end
    end
  end

  describe "create" do
    let(:feedback_attrs) do
      {
        name: "something cool",
        email: "example@stuff.com",
        title: "a title and things",
        body: "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod
              tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
              quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
              consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
              cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
              proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
      }
    end
    let!(:user) { FactoryBot.create(:user_confirmed) }

    # Nothing else covers ApplicationController's own handler - the controllers that
    # override it never reach this branch
    context "with a null origin" do
      include_context :test_csrf_token

      it "redirects with the CSRF explanation rather than a missing translation" do
        expect {
          post base_url, params: {feedback: feedback_attrs}, headers: {"HTTP_ORIGIN" => "null"}
        }.to_not change(Feedback, :count)
        expect(response).to redirect_to root_url
        expect(flash[:error]).to match(/try again.*a VPN/i)
      end
    end

    context "valid feedback" do
      it "creates a feedback message" do
        expect(user.name).to be_present
        log_in(user)
        expect {
          post base_url, params: {feedback: feedback_attrs.except(:email, :name)}
        }.to change(EmailJobs::FeedbackNotificationJob.jobs, :count).by(1)
        expect(response).to redirect_to help_path
        expect(flash[:success]).to be_present
        feedback = Feedback.last
        feedback_attrs.except(:email, :name).each { |k, v| expect(feedback.send(k)).to eq(v) }
        expect(feedback.user).to eq user
        expect(feedback.email).to eq user.email
        expect(feedback.name).to eq user.name
      end
    end

    context "feedback with generated title" do
      it "creates a feedback" do
        expect {
          post base_url, params: {
                           feedback: {
                             name: "Cool School",
                             feedback_type: "lead_for_school",
                             email: "example@example.com",
                             body: "ffff",
                             package_size: "small"
                           }
                         },
            headers: {"HTTP_REFERER" => "http://www.example.com/partyyyyy"}
        }.to change(EmailJobs::FeedbackNotificationJob.jobs, :count).by(1)
        expect(response).to redirect_to "http://www.example.com/partyyyyy"
        expect(flash[:success]).to be_present
        feedback = Feedback.last
        expect(feedback.title).to eq "New School lead: Cool School"
        expect(feedback.email).to eq "example@example.com"
        expect(feedback.body).to eq "ffff"
        expect(feedback.feedback_hash["package_size"]).to eq "small"
      end
      context "with a phone number and no package_size" do
        it "creates a feedback" do
          expect {
            post base_url, params: {
                             feedback: {
                               name: "Chicago",
                               feedback_type: "lead_for_city",
                               email: "example@example.com",
                               phone_number: "891024123",
                               package_size: ""
                             }
                           },
              headers: {"HTTP_REFERER" => "http://www.example.com/for_cities"}
          }.to change(EmailJobs::FeedbackNotificationJob.jobs, :count).by(1)
          expect(response).to redirect_to "http://www.example.com/for_cities"
          expect(flash[:success]).to be_present
          feedback = Feedback.last
          expect(feedback.title).to eq "New City lead: Chicago"
          expect(feedback.email).to eq "example@example.com"
          expect(feedback.phone_number).to eq "891024123"
          expect(feedback.package_size).to eq ""
        end
      end

      context "from the bike shops page" do
        let(:lead_params) { {name: "Spoke Shop", feedback_type: "lead_for_bike_shop", email: "shop@example.com", body: "POS: Ascend"} }

        it "returns a signup to the thank you, after a failed submit left the referer at /feedbacks" do
          post base_url, params: {feedback: lead_params.merge(email: " "), return_to: "/for_bike_shops#shop-signed-up"},
            headers: {"HTTP_REFERER" => "http://www.example.com/for_bike_shops"}
          expect(response).to render_template("landing_pages/for_bike_shops")
          expect(response.body).to include("Spoke Shop", "Email can&#39;t be blank")

          expect {
            post base_url, params: {feedback: lead_params, return_to: "/for_bike_shops#shop-signed-up"},
              headers: {"HTTP_REFERER" => "http://www.example.com/feedbacks"}
          }.to change(EmailJobs::FeedbackNotificationJob.jobs, :count).by(1)
          expect(response).to redirect_to "http://www.example.com/for_bike_shops#shop-signed-up"
          expect(Feedback.last).to have_attributes(kind: "lead_for_bike_shop", title: "New Bike shop lead: Spoke Shop", body: "POS: Ascend")
        end
      end

      context "from a demo modal that names where to return" do
        let(:lead_params) { {name: "Chicago", feedback_type: "lead_for_city", email: "example@example.com"} }

        it "re-renders and returns there, not at the /feedbacks a failed submit left as the referer" do
          post base_url, params: {feedback: lead_params.merge(email: " "), return_to: "/for_cities#lead-sent"},
            headers: {"HTTP_REFERER" => "http://www.example.com/feedbacks", "HTTP_CF_IPCOUNTRY" => "US", "HTTP_CF_REGION" => "Indiana"}
          expect(response).to render_template("landing_pages/for_cities")
          expect(Capybara.string(response.body)).to have_field("state", type: :hidden, with: "US-IN")

          post base_url, params: {feedback: lead_params, return_to: "/for_cities#lead-sent"},
            headers: {"HTTP_REFERER" => "http://www.example.com/feedbacks"}
          expect(response).to redirect_to "http://www.example.com/for_cities#lead-sent"

          post base_url, params: {feedback: lead_params, return_to: "https://evil.example.org/for_cities"},
            headers: {"HTTP_REFERER" => "http://www.example.com/for_cities"}
          expect(response).to redirect_to "http://www.example.com/for_cities"
        end
      end
    end

    context "feedback with additional" do
      it "does not create a feedback message" do
        expect {
          post base_url, params: {feedback: feedback_attrs.merge(additional: "stuff")},
            headers: {"HTTP_REFERER" => for_schools_url}
        }.to_not change(EmailJobs::FeedbackNotificationJob.jobs, :count)
        expect(flash[:error]).to match(/sign in/i)
      end
    end

    context "invalid feedback" do
      context "no referrer" do
        it "does not create a feedback message" do
          expect {
            post base_url, params: {feedback: feedback_attrs.merge(email: "")}
          }.to change(EmailJobs::FeedbackNotificationJob.jobs, :count).by(0)

          expect(response).to render_template(:index)
          feedback = assigns(:feedback)
          feedback_attrs.except(:email).each { |k, v| expect(feedback.send(k)).to eq(v) }
          expect(assigns(:page_errors).full_messages.to_s).to match "Email can't be blank"
        end
      end
      context "referrer set" do
        it "does not create a feedback message" do
          log_in(user)
          expect {
            post base_url, params: {feedback: feedback_attrs.merge(body: "")},
              headers: {"HTTP_REFERER" => "http://www.example.com/for_schools"}
          }.to change(EmailJobs::FeedbackNotificationJob.jobs, :count).by(0)
          expect(response).to render_template("landing_pages/for_schools")
          feedback = assigns(:feedback)
          feedback_attrs.except(:body).each { |k, v| expect(feedback.send(k)).to eq(v) }
          expect(assigns(:page_errors).full_messages.to_s).to match "Body can't be blank"
        end
      end
    end
  end
end
