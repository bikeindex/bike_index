require "rails_helper"

base_url = "/feedbacks"
RSpec.describe FeedbacksController, type: :request do
  describe "index" do
    it "renders with revised_layout" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
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

    context "valid feedback" do
      it "creates a feedback message" do
        expect(user.name).to be_present
        log_in(user)
        expect {
          post base_url, params: {feedback: feedback_attrs.except(:email, :name)}
        }.to change(Email::FeedbackNotificationJob.jobs, :count).by(1)
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
            headers: {"HTTP_REFERER" => "http://localhost:3000/partyyyyy"}
        }.to change(Email::FeedbackNotificationJob.jobs, :count).by(1)
        expect(response).to redirect_to "http://localhost:3000/partyyyyy"
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
              headers: {"HTTP_REFERER" => "http://localhost:3000/cities_packages"}
          }.to change(Email::FeedbackNotificationJob.jobs, :count).by(1)
          expect(response).to redirect_to "http://localhost:3000/cities_packages"
          expect(flash[:success]).to be_present
          feedback = Feedback.last
          expect(feedback.title).to eq "New City lead: Chicago"
          expect(feedback.email).to eq "example@example.com"
          expect(feedback.phone_number).to eq "891024123"
          expect(feedback.package_size).to eq ""
        end
      end
    end

    context "feedback with additional" do
      it "does not create a feedback message" do
        expect {
          post base_url, params: {feedback: feedback_attrs.merge(additional: "stuff")},
            headers: {"HTTP_REFERER" => for_schools_url}
        }.to_not change(Email::FeedbackNotificationJob.jobs, :count)
        expect(flash[:error]).to match(/sign in/i)
      end
    end

    context "invalid feedback" do
      context "no referrer" do
        it "does not create a feedback message" do
          expect {
            post base_url, params: {feedback: feedback_attrs.merge(email: "")}
          }.to change(Email::FeedbackNotificationJob.jobs, :count).by(0)

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
              headers: {"HTTP_REFERER" => for_schools_url}
          }.to change(Email::FeedbackNotificationJob.jobs, :count).by(0)
          expect(response).to render_template("landing_pages/for_schools")
          feedback = assigns(:feedback)
          feedback_attrs.except(:body).each { |k, v| expect(feedback.send(k)).to eq(v) }
          expect(assigns(:page_errors).full_messages.to_s).to match "Body can't be blank"
        end
      end
    end
  end
end
