# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::MainContent::Organized::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:action_name) { "index" }
  let(:component) do
    render_inline(described_class.new(current_organization: organization, current_user: nil,
      passive_organization: organization, show_general_alert: false, controller_name:, action_name:))
  end
  let(:container_class) { component.at_css(".organized-wrap > div")["class"] }
  let(:javascript_pack) { component.css("script[src='/vendored_assets/application.js']").any? }

  context "users" do
    let(:controller_name) { "users" }
    it "is a container, without the legacy bundle" do
      expect(container_class).to eq "container"
      expect(javascript_pack).to be_falsey
    end
  end

  context "registrations" do
    let(:controller_name) { "registrations" }
    it "is fluid, with the legacy bundle" do
      expect(container_class).to eq "container-fluid"
      expect(javascript_pack).to be_truthy
    end

    context "new" do
      let(:action_name) { "new" }
      it "has no container, and no legacy bundle" do
        expect(container_class).to be_blank
        expect(javascript_pack).to be_falsey
      end
    end
  end

  context "bulk_imports" do
    let(:controller_name) { "bulk_imports" }
    it "is a container" do
      expect(container_class).to eq "container"
    end

    context "show" do
      let(:action_name) { "show" }
      it "is fluid" do
        expect(container_class).to eq "container-fluid"
      end
    end
  end

  context "bikes recoveries" do
    let(:controller_name) { "bikes" }
    let(:action_name) { "recoveries" }
    it "is a container, with the legacy bundle" do
      expect(container_class).to eq "container"
      expect(javascript_pack).to be_truthy
    end
  end
end
