require 'spec_helper'

describe FeedbacksController do
  describe 'index' do
    it 'renders with revised_layout' do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(response).to render_with_layout('application_revised')
    end
  end

  describe 'create' do
    let(:feedback_attrs) do
      {
        name: 'something cool',
        email: 'example@stuff.com',
        title: 'a title and things',
        body: 'Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod
              tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
              quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
              consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
              cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
              proident, sunt in culpa qui officia deserunt mollit anim id est laborum.'
      }
    end
    let(:user) { FactoryGirl.create(:user) }

    context 'valid feedback' do
      it 'creates a feedback message' do
        set_current_user(user)
        expect do
          post :create, feedback: feedback_attrs
        end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(1)
        expect(response).to redirect_to help_path
        expect(flash[:success]).to be_present
        feedback = Feedback.last
        feedback_attrs.each { |k, v| expect(feedback.send(k)).to eq(v) }
      end
    end

    context 'invalid feedback' do
      it 'creates a feedback message' do
        set_current_user(user)
        expect do
          post :create, feedback: feedback_attrs.merge(email: '')
        end.to change(EmailFeedbackNotificationWorker.jobs, :size).by(0)
        expect(response).to render_template(:index)
        feedback = assigns(:feedback)
        feedback_attrs.except(:email).each { |k, v| expect(feedback.send(k)).to eq(v) }
        expect(assigns(:page_errors).full_messages.to_s).to match "Email can't be blank"
      end
    end
  end
end
