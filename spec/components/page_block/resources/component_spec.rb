# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::Resources::Component, type: :component do
  let(:component) { render_inline(described_class.new) }

  it "renders all sections" do
    expect(component).to have_css(".le-hero-section")
    expect(component).to have_css("#design-resources")
    expect(component).to have_css("#dev-resources")
    expect(component).to have_css(".le-cta-section")
    expect(component).to have_text("Resources & Marketing Materials")
  end

  it "renders design resources with download links" do
    expect(component).to have_text("Downloadable Logos")
    expect(component).to have_text("Graphics Pack")
    expect(component).to have_css("a.resource-btn[download]", count: 6)
  end

  it "only opens external dev resource links in new tabs" do
    expect(component).to have_css("a.dev-resource-link", count: 6)
    expect(component).to have_css("a.dev-resource-link[target='_blank']", count: 2)
    expect(component).to have_link("View API Docs", href: "/documentation")
    expect(component).to have_link("Manage Applications", href: "/oauth/applications")
  end

  context "with no current_user" do
    it "links the bike display widget to sign up" do
      expect(component).to have_link("Get Widget Code", href: "/users/new?return_to=%2Fresources")
    end
  end

  context "with a current_user" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    let(:component) { render_inline(described_class.new(current_user:)) }

    it "links the bike display widget to the user embed" do
      expect(component).to have_link("Get Widget Code", href: "/user_embeds/#{current_user.username}")
    end
  end
end
