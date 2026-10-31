# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Users::Tabs::Component, type: :component do
  let(:user) { FactoryBot.create(:user_confirmed, name: "Test User") }
  let(:active) { :edit }
  let(:component) { render_inline(described_class.new(user:, active:)) }
  let(:tab_labels) { component.css("nav a").map { |tab| tab.text.squish } }

  it "renders the user and every tab, with the active one marked" do
    FactoryBot.create(:user_email, user:)
    expect(component).to have_content("Test User")
    expect(tab_labels).to eq ["Edit", "Bikes 0", "Messages 0", "Memberships 0", "Alerts 0", "Payments 0",
      "Organizations 0", "Notifications 0", "Feedbacks 0", "Emails 2"]
    expect(component.css("nav a[aria-current]").map { |tab| tab.text.squish }).to eq ["Edit"]
    expect(component).to have_link("Edit", href: "/admin/users/#{user.id}/edit")
    expect(component).to have_link("Bikes 0", href: "/admin/bikes?user_id=#{user.id}")
    expect(component).to have_link("Payments 0", href: "/admin/payments?user_id=#{user.id}")
    expect(component).to have_link("Emails 2", href: "/admin/users/#{user.id}?active_tab=emails")
    expect(component.css("[role='alert']")).to be_empty
    expect(component).to_not have_content("deleted")
  end

  context "with deleted bikes" do
    before { FactoryBot.create_list(:bike, 2, :with_ownership_claimed, user:, deleted_at: Time.current) }

    it "links to them" do
      expect(component).to have_link("2 deleted bikes",
        href: "/admin/bikes?search_status_deleted_only=true&search_status_example=true&user_id=#{user.id}")
    end
  end

  context "with caching", :caching do
    include_context :caching_basic

    def rendered = render_inline(described_class.new(user:, active:))

    it "keeps the counts until the user changes" do
      expect(rendered).to have_link("Bikes 0")
      FactoryBot.create(:bike, :with_ownership_claimed, user:)
      expect(rendered).to have_link("Bikes 0")
      user.touch
      expect(rendered).to have_link("Bikes 1")
    end
  end

  context "with an invalid active tab" do
    let(:active) { :party }

    it "raises" do
      expect { component }.to raise_error(ArgumentError, /party/)
    end
  end

  # The page renders either way, so it can't be the one tab that vanishes underneath itself
  context "on the ambassador tasks tab, for a user who isn't one" do
    let(:active) { :ambassador_tasks }

    it "renders it, active" do
      expect(component.css("nav a[aria-current]").map { |tab| tab.text.squish }).to eq ["Ambassador tasks 0"]
    end
  end

  describe "alerts" do
    context "with deleted user" do
      let(:user) { FactoryBot.create(:user_confirmed, deleted_at: Time.current) }

      it "renders the deleted alert" do
        expect(component).to have_content("User deleted")
      end
    end

    context "with banned user" do
      let(:user) { FactoryBot.create(:user_confirmed, banned: true) }
      let!(:user_ban) { UserBan.create(user:, reason: :extortion) }

      it "renders the banned alert" do
        expect(component).to have_content("User banned")
        expect(component).to have_content("Extortion")
      end
    end

    context "with an email_ban on an additional address" do
      let(:user_email) { FactoryBot.create(:user_email, user:, email: "other@example.com") }
      let!(:email_ban) { FactoryBot.create(:email_ban, user:, user_email:, reason: :email_duplicate) }

      it "renders the ban and the address it names" do
        expect(user.reload.email_banned?).to be_falsey
        expect(component).to have_content("User's email banned")
        expect(component).to have_content("other@example.com")
      end
    end
  end
end
