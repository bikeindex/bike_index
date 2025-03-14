require "rails_helper"

RSpec.describe HeaderTagHelper, type: :helper do
  describe "header_tags_component_options" do
    before do
      helper.extend(ControllerHelpers)
      allow(view).to receive(:controller_name) { controller_name }
      allow(view).to receive(:action_name) { action_name }
      # These two methods are defined in application controller
      allow(view).to receive(:controller_namespace) { controller_namespace }
      allow(helper).to receive(:current_organization) { current_organization }
    end
    let(:controller_namespace) { nil }
    let(:action_name) { "index" }
    let(:target) do
      {
        page_title:,
        page_obj:,
        updated_at: nil,
        organization_name: nil,
        controller_name:,
        controller_namespace:,
        action_name:,
        request_url: "http://test.host",
        language: :en
      }
    end
    let(:page_title) { nil }
    let(:page_description) { nil }
    let(:page_obj) { nil }
    let(:current_organization) { nil }

    context "controller_name: info" do
      let(:controller_name) { "info" }
      context "action_name: about" do
        let(:action_name) { "about" }
        it "responds with target" do
          expect(header_tags_component_options).to eq target
        end
      end
    end
    context "bikes" do
      let(:controller_name) { "bikes" }
      it "renders" do
        expect(header_tags_component_options).to eq target
      end
    end
  end
end
