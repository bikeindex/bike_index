require 'spec_helper'

describe ErrorsController do
  describe 'bad_request' do
    before do
      get :bad_request
    end
    it { is_expected.to respond_with(:bad_request) }
    it { is_expected.to render_template(:bad_request) }
  end

  describe 'not_found' do
    before do
      get :not_found
    end
    it { is_expected.to respond_with(:not_found) }
    it { is_expected.to render_template(:not_found) }
  end

  describe 'unprocessable_entity' do
    before do
      get :unprocessable_entity, format: :xml
    end
    it { is_expected.to respond_with(:unprocessable_entity) }
    it { is_expected.to render_template(:unprocessable_entity) }
  end

  # Since this renders a 500, it doesn't test right.
  # describe 'server_error' do
  #   before do
  #     get :server_error, format: :xml
  #   end
  #   it { should respond_with(:server_error) }
  #   it { should render_template(:server_error) }
  # end

  describe 'unauthorized' do
    before do
      get :unauthorized, format: :json
    end
    it { is_expected.to respond_with(:unauthorized) }
    it { is_expected.to render_template(:unauthorized) }
  end
end
