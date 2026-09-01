# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::SocialPosts::Form::Component, type: :component do
  let(:social_post) { SocialPost.new(kind:) }
  let(:kind) { "app_post" }
  let(:component) { render_inline(described_class.new(social_post:)) }
  let(:kind_fields) { component.css("[data-admin--social-post-form-target='kindFields']") }

  def fields_for(kind) = kind_fields.find { |el| el["data-kind"] == kind }

  it "wires the kind select, the counter and the repost buttons" do
    expect(component.css("[data-controller='admin--social-post-form']").count).to eq 1
    expect(component.css("[data-admin--social-post-form-target='kind']").count).to eq 1
    expect(component.css("[data-admin--social-post-form-target='characterCounter']").count).to eq 1
    expect(component.css("[data-admin--social-post-form-target='characterTotal']").count).to eq 1
    expect(kind_fields.map { |el| el["data-kind"] }).to match_array(%w[app_post imported_post])
    expect(component.css("[data-admin--social-post-form-max-character-count-value]").count).to eq 1
  end

  context "when sending a post" do
    it "shows the app_post fields only" do
      expect(fields_for("app_post")["class"]).to_not match("tw:hidden")
      expect(fields_for("imported_post")["class"]).to match("tw:hidden!")
    end
  end

  context "with social accounts" do
    let!(:active_account) { FactoryBot.create(:social_account, account_info: {name: "a"}, active: true, screen_name: "activeAccount") }
    let!(:inactive_account) { FactoryBot.create(:social_account, account_info: {name: "b"}, active: false, screen_name: "inactiveAccount") }

    # Any account can send the post; only a live one can repost it
    it "offers both to send from, but only the active one to repost" do
      expect(component.to_html).to include("activeAccount").and include("inactiveAccount")

      checkboxes = component.css("[data-admin--social-post-form-target='accountCheckbox']")
      expect(checkboxes.map { |el| el["value"] }).to eq [active_account.id.to_s]
    end
  end

  context "when importing a post" do
    let(:kind) { "imported_post" }

    it "shows the imported_post fields only" do
      expect(fields_for("imported_post")["class"]).to_not match("tw:hidden")
      expect(fields_for("app_post")["class"]).to match("tw:hidden!")
    end
  end
end
