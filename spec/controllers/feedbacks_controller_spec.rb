require 'spec_helper'

describe FeedbacksController do
  it 'renders with revised_layout' do
    get :index
    expect(response.status).to eq(200)
    expect(response).to render_template(:index)
    expect(response).to render_with_layout('application_revised')
  end
end

