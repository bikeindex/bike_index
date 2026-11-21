require "rails_helper"

RSpec.describe ApplicationController, type: :request do
  describe "rendering a template that doesn't exist in the requested format" do
    it "is not acceptable" do
      get "/users/new", headers: {"Accept" => "application/json"}
      expect(response).to have_http_status(:not_acceptable)

      get "/users/new", headers: {"Accept" => "text/vnd.turbo-stream.html"}
      expect(response).to have_http_status(:not_acceptable)
    end

    context "when it doesn't exist in any format" do
      around do |example|
        view_paths = UsersController.view_paths
        UsersController.view_paths = []
        example.run
      ensure
        UsersController.view_paths = view_paths
      end

      it "raises, whatever the format" do
        expect { get "/users/new" }.to raise_error(ActionView::MissingTemplate)
        expect { get "/users/new", headers: {"Accept" => "text/vnd.turbo-stream.html"} }
          .to raise_error(ActionView::MissingTemplate)
        expect { get "/users/new", headers: {"Accept" => "application/json"} }
          .to raise_error(ActionView::MissingTemplate)
      end
    end
  end
end
