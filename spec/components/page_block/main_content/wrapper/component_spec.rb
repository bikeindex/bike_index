# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::MainContent::Wrapper::Component, type: :component do
  describe "kind" do
    let(:controller_namespace) { nil }
    let(:action_name) { "index" }
    let(:force_landing_page_render) { false }
    subject(:kind) do
      described_class.kind(controller_namespace:, controller_name:, action_name:,
        force_landing_page_render:)
    end

    context "landing_pages controller" do
      let(:controller_name) { "landing_pages" }
      %w[show for_law_enfocement for_schools].each do |action|
        context action do
          let(:action_name) { action }
          it { is_expected.to be_nil }
        end
      end
    end
    context "bikes controller" do
      let(:controller_name) { "bikes" }
      %w[new create].each do |action|
        context action do
          let(:action_name) { action }
          it { is_expected.to be_nil }
        end
      end
      context "update" do
        let(:action_name) { "update" }
        it { is_expected.to eq :edit_bike }
      end
    end
    context "registrations controller" do
      let(:controller_name) { "registrations" }
      context "new" do
        let(:action_name) { "new" }
        it { is_expected.to eq :content }
      end
      context "show" do
        let(:action_name) { "show" }
        it { is_expected.to be_nil }
      end
      context "search namespace" do
        let(:controller_namespace) { "search" }
        it { is_expected.to be_nil }
      end
    end
    context "info controller" do
      let(:controller_name) { "info" }
      %w[about protect_your_bike where serials].each do |action|
        context action do
          let(:action_name) { action }
          it { is_expected.to eq :content }
        end
      end
      %w[terms vendor_terms security privacy resources support_the_index].each do |action|
        context action do
          let(:action_name) { action }
          it { is_expected.to be_nil }
        end
      end
    end
    context "bike edit pages" do
      context "edits" do
        let(:controller_name) { "edits" }
        let(:action_name) { "show" }
        it { is_expected.to eq :edit_bike }
      end
      context "theft_alerts" do
        let(:controller_name) { "theft_alerts" }
        %w[new show].each do |action|
          context action do
            let(:action_name) { action }
            it { is_expected.to eq :edit_bike }
          end
        end
      end
      context "recovery" do
        let(:controller_name) { "recovery" }
        let(:action_name) { "edit" }
        it { is_expected.to eq :edit_bike }
      end
    end
    context "news controller" do
      let(:controller_name) { "news" }
      %w[index show].each do |action|
        context action do
          let(:action_name) { action }
          it { is_expected.to eq :content }
        end
      end
    end
    context "payments controller" do
      let(:controller_name) { "payments" }
      %w[new create].each do |action|
        context action do
          let(:action_name) { action }
          it { is_expected.to be_nil }
        end
      end
    end
    context "feedbacks controller" do
      let(:controller_name) { "feedbacks" }
      it { is_expected.to eq :content }
    end
    context "manufacturers controller" do
      let(:controller_name) { "manufacturers" }
      it { is_expected.to eq :content }
    end
    context "welcome controller" do
      let(:controller_name) { "welcome" }
      context "goodbye" do
        let(:action_name) { "goodbye" }
        it { is_expected.to eq :content }
      end
      context "index" do
        it { is_expected.to be_nil }
      end
    end
    context "organizations controller" do
      let(:controller_name) { "organizations" }
      context "lightspeed_integration" do
        let(:action_name) { "lightspeed_integration" }
        it { is_expected.to eq :content }
      end
      context "new" do
        let(:action_name) { "new" }
        it { is_expected.to be_nil }
      end
    end
    context "oauth namespace" do
      let(:controller_namespace) { "oauth" }
      context "applications" do
        let(:controller_name) { "applications" }
        it { is_expected.to eq :oauth_applications }
      end
      context "authorizations" do
        let(:controller_name) { "authorizations" }
        it { is_expected.to be_nil }
      end
    end
    context "organized namespace" do
      let(:controller_namespace) { "organized" }
      %w[manage bikes users].each do |controller|
        context controller do
          let(:controller_name) { controller }
          it { is_expected.to eq :organized }
        end
      end
      context "landing" do
        let(:controller_name) { "landing_pages" }
        let(:action_name) { "landing" }
        it { is_expected.to be_nil }
      end
    end
    context "stolen controller" do
      let(:controller_name) { "stolen" }
      it { is_expected.to be_nil }
    end
    context "errors controller" do
      let(:controller_name) { "errors" }
      %w[bad_request not_found unprocessable_entity server_error unauthorized].each do |action|
        context action do
          let(:action_name) { action }
          it { is_expected.to eq :content }
        end
      end
    end
    context "force_landing_page_render" do
      let(:controller_name) { "news" }
      let(:force_landing_page_render) { true }
      it { is_expected.to be_nil }
    end
  end

  describe "render" do
    let(:page) { "<p>the page</p>".html_safe }
    let(:result) { render_inline(described_class.new(**options)) { page } }

    context "no wrapper" do
      let(:options) { {controller_namespace: nil, controller_name: "welcome", action_name: "index"} }

      it "renders the content, unwrapped" do
        expect(result.to_html.strip).to eq "<p>the page</p>"
      end
    end

    context "content" do
      let(:options) { {controller_namespace: nil, controller_name: "info", action_name: "about"} }

      it "renders the content wrapper around the page" do
        expect(result.css(".primary-content-block").to_html).to match "<p>the page</p>"
        expect(result.text).to match "Other pages"
      end
    end

    context "edit_bike" do
      let(:bike) { FactoryBot.create(:bike, :with_ownership) }
      let(:options) do
        {controller_namespace: nil, controller_name: "edits", action_name: "show", bike:,
         edit_template: "bike_details", edit_templates: {"bike_details" => "Details"}}
      end

      # bikes/_owner_bike_status_alerts is a view, and reads the bike off the controller;
      # edit_bike_template_path_for comes from BikeEditable, which only the edit
      # controllers include. Must be on the class, not the singleton, to avoid leaking
      before do
        vc_test_controller.instance_variable_set(:@bike, bike)
        unless vc_test_controller.class.method_defined?(:edit_bike_template_path_for)
          vc_test_controller.class.define_method(:edit_bike_template_path_for) do |bike, template = nil|
            "/bikes/#{bike.id}/edit/#{template}"
          end
          vc_test_controller.class.helper_method :edit_bike_template_path_for
        end
      end

      it "renders the edit header and menu around the page" do
        expect(result.css("#edit-bike-skeleton").to_html).to match "<p>the page</p>"
        expect(result.text).to match "Details"
        expect(result.css(".bike-status-html").count).to eq 0
        expect(result.text).to match bike.mnfg_name
      end

      context "not with its owner" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership, :with_stolen_record) }

        it "renders the status in place of the edit heading" do
          expect(result.css(".bike-status-html").text).to match(/stolen/i)
        end
      end
    end

    context "oauth_applications" do
      let(:options) do
        {controller_namespace: "oauth", controller_name: "applications", action_name: "index"}
      end

      it "renders the doorkeeper container around the page" do
        expect(result.css(".doorkeeper-container").to_html).to match "<p>the page</p>"
      end
    end

    context "organized" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:options) do
        {controller_namespace: "organized", controller_name: "bikes", action_name: "index",
         current_organization: organization}
      end

      it "renders the page without a menu" do
        expect(result.css(".organized-wrap").to_html).to match "<p>the page</p>"
        expect(result.text).to_not match "Admin Panel"
      end
    end
  end
end
