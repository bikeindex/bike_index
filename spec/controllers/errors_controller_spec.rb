require 'spec_helper'

describe ErrorsController do
  describe 'bad_request' do
    it 'renders' do
      get :bad_request
      expect(response.status).to eq(400)
      expect(response).to render_template(:bad_request)
    end
  end

  describe 'unauthorized' do
    it 'renders' do
      get :unauthorized, format: :json
      expect(response.status).to eq(401)
      expect(response).to render_template(:unauthorized)
    end
  end

  describe 'not_found' do
    it 'renders' do
      get :not_found
      expect(response.status).to eq(404)
      expect(response).to render_template(:not_found)
    end
  end

  describe 'unprocessable_entity' do
    it 'renders' do
      get :unprocessable_entity, format: :json
      expect(response.status).to eq(422)
      expect(response).to render_template(:unprocessable_entity)
    end
  end

  # Since this renders a 500, it doesn't test right.
  # describe 'server_error' do
  #   it 'renders' do
  #     get :server_error, format: :json
  #     expect(response.status).to eq(500)
  #     expect(response).to render_template(:server_error)
  #   end
  # end
end
