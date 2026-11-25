# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Users::Show::Bikes::Component, type: :component do
  let(:user) { FactoryBot.create(:user_confirmed) }
  let(:component) { with_request_url("/admin/users/#{user.id}?active_tab=bikes") { render_inline(described_class.new(user:)) } }
  let(:heading) { component.at_css("h2").text.squish }

  it "says there are none" do
    expect(heading).to eq "Bikes 0 (view in admin/bikes)"
    expect(component).to have_link("admin/bikes", href: "/admin/bikes?user_id=#{user.id}")
  end

  context "with more bikes than it shows" do
    before do
      stub_const("#{described_class}::LIMIT", 1)
      FactoryBot.create_list(:bike, 2, :with_ownership_claimed, user:)
    end

    it "says how many it shows" do
      expect(heading).to eq "Bikes 2 (first 1 shown, view all in admin/bikes)"
      expect(component.css("table tbody tr").count).to eq 1
    end
  end

  context "with deleted bikes" do
    before { FactoryBot.create(:bike, :with_ownership_claimed, user:, deleted_at: Time.current) }

    it "counts them after" do
      expect(heading).to eq "Bikes 0 (view in admin/bikes) - 1 deleted bike"
      expect(component).to have_link("1 deleted bike",
        href: "/admin/bikes?search_status_deleted_only=true&search_status_example=true&user_id=#{user.id}")
    end
  end
end
