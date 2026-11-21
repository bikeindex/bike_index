require "rails_helper"

RSpec.describe ApplicationController, type: :request do
  describe "rendering an HTML-only template" do
    it "is not acceptable as json" do
      get "/users/new", headers: {"Accept" => "application/json"}
      expect(response).to have_http_status(:not_acceptable)
    end

    context "with no template at all" do
      let(:controller_class) do
        Class.new(ApplicationController) do
          def self.name = "MissingTemplateTestController"

          def show = render(:show)
        end
      end

      before { stub_const("MissingTemplateTestController", controller_class) }

      it "raises for html, including a Turbo form submission" do
        with_routing do |routes|
          routes.draw { post "missing_template" => "missing_template_test#show" }

          expect { post "/missing_template" }.to raise_error(ActionView::MissingTemplate)
          turbo_accept = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"
          expect { post "/missing_template", headers: {"Accept" => turbo_accept} }
            .to raise_error(ActionView::MissingTemplate)
        end
      end
    end
  end
end
