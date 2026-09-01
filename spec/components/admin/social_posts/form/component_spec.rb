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
  end

  # The counter reads the limit from the controller rather than a window global
  it "passes the character limit as a value" do
    expect(component.css("[data-admin--social-post-form-max-character-count-value]").first["data-admin--social-post-form-max-character-count-value"])
      .to eq Integrations::SocialPoster::TWEET_LENGTH.to_s
  end

  context "when sending a post" do
    it "shows the app_post fields only" do
      expect(fields_for("app_post")["class"]).to_not match("tw:hidden")
      expect(fields_for("imported_post")["class"]).to match("tw:hidden")
    end
  end

  context "when importing a post" do
    let(:kind) { "imported_post" }

    it "shows the imported_post fields only" do
      expect(fields_for("imported_post")["class"]).to_not match("tw:hidden")
      expect(fields_for("app_post")["class"]).to match("tw:hidden")
    end
  end
end
