# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Users::Edit::Component, type: :component do
  let(:user) { FactoryBot.create(:user) }
  let(:component) { render_inline(described_class.new(user:)) }
  let(:ban_fields) { component.css("[data-admin--user-edit-form-target='banFields']") }
  let(:ban_reason) { component.css("[data-admin--user-edit-form-target='banReason']") }

  it "renders the form with the banned checkbox wired to the ban fields" do
    expect(component.css("form[data-controller='admin--user-edit-form']").count).to eq 1
    expect(component.css("[data-admin--user-edit-form-target='banned']").count).to eq 1
  end

  context "when not banned" do
    it "renders the ban fields collapsed, with the reason not required" do
      expect(ban_fields.first["class"]).to match("tw:hidden")
      expect(ban_reason.first["required"]).to be_blank
    end
  end

  context "when banned" do
    let(:user) { FactoryBot.create(:user, banned: true) }

    # The server renders the open state, so the panel doesn't have to flash shut on load
    it "renders the ban fields open, with the reason required" do
      expect(ban_fields.first["class"]).to_not match("tw:hidden")
      expect(ban_reason.first["required"]).to be_present
    end
  end

  context "with a ban reason already recorded" do
    let(:user) { FactoryBot.create(:user, banned: true) }
    let!(:user_ban) { UserBan.create(user:, creator: FactoryBot.create(:user), reason: :abuse) }

    it "drops the ban fields" do
      expect(ban_fields).to be_empty
    end
  end

  context "with display_dev_info" do
    let(:component) { render_inline(described_class.new(user:, display_dev_info: true)) }

    it "renders the developer checkbox" do
      expect(component.css("#user_developer").count).to eq 1
    end
  end
end
