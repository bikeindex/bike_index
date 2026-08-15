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

  describe "organized?" do
    let(:instance) do
      described_class.new(controller_namespace:, controller_name: "bikes", action_name: "index")
    end
    subject { instance.organized? }

    context "organized namespace" do
      let(:controller_namespace) { "organized" }
      it { is_expected.to be_truthy }
    end
    context "no namespace" do
      let(:controller_namespace) { nil }
      it { is_expected.to be_falsey }
    end
  end

  describe "render" do
    let(:instance) do
      described_class.new(controller_namespace: nil, controller_name: "welcome", action_name: "index")
    end

    it "renders the content, unwrapped" do
      result = render_inline(instance) { "<p>the page</p>".html_safe }
      expect(result.to_html.strip).to eq "<p>the page</p>"
    end
  end
end
