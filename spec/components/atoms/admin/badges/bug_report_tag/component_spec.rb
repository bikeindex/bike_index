# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::Admin::Badges::BugReportTag::Component, type: :component do
  def badge_class(tag) = render_inline(described_class.new(tag:)).css("span").first["class"]

  it "colors by prefix, then by tag" do
    expect(badge_class("ask_stolen_bike")).to eq badge_class("ask_sign_in_help")
    expect(badge_class("area_emails")).to eq badge_class("area_search")
    expect(badge_class("area_emails")).not_to eq badge_class("ask_sign_in_help")
    colors = %w[bug spam feedback auto_replies bike_index_notification].map { badge_class(it) }
    expect(colors.uniq.length).to eq 5
    expect(colors).not_to include(badge_class("ask_sign_in_help"), badge_class("area_emails"))
    expect(badge_class("parking")).to eq badge_class("parking")
  end
end
