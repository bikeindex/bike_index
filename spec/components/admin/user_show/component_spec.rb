# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::UserShow::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {user:, bikes:, bikes_count:} }
  let(:user) { FactoryBot.create(:user_confirmed, name: "Test User") }
  let(:bikes) { [] }
  let(:bikes_count) { 0 }

  it "renders user display name" do
    expect(component).to have_css("h1", text: /Test User/)
  end

  it "renders user email" do
    expect(component).to have_content(user.email)
  end

  it "renders bikes count" do
    expect(component).to have_css("h4", text: /Bikes/)
    expect(component).to have_link(href: /user_id=#{user.id}/)
  end

  context "with deleted user" do
    let(:user) { FactoryBot.create(:user_confirmed, deleted_at: Time.current) }

    it "renders deleted alert" do
      expect(component).to have_css(".alert-danger", text: /User deleted/)
    end
  end

  context "with banned user" do
    let(:user) { FactoryBot.create(:user_confirmed, banned: true) }
    let!(:user_ban) { UserBan.create(user:, reason: :extortion) }

    it "renders banned alert" do
      expect(component).to have_css("h4.text-danger", text: /User banned/)
      expect(component).to have_content("Extortion")
    end
  end

  context "with superuser" do
    let(:user) { FactoryBot.create(:superuser) }
    let!(:superuser_ability) { SuperuserAbility.create(user:) }

    it "renders superuser info" do
      expect(component).to have_content("full superuser")
    end
  end
end
