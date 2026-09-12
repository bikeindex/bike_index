# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin bikes", :js, type: :system do
  let(:superuser) { FactoryBot.create(:superuser) }
  let(:bike) { FactoryBot.create(:bike) }

  before do
    Organization.example && Cgroup.additional_parts # Read replica
    sign_in(superuser)
  end

  # Whether the confirm actually holds the request back is only observable in a browser
  it "asks before deleting a bike, and deletes it only once confirmed" do
    visit "/admin/bikes/#{bike.id}/edit"

    expect(dismiss_confirm { click_button "Delete bike" }).to eq "Are you sure?"
    expect(page).to have_current_path("/admin/bikes/#{bike.id}/edit")
    expect(bike.reload.deleted_at).to be_nil

    accept_confirm { click_button "Delete bike" }

    expect(page).to have_content("Bike deleted!")
    expect(bike.reload.deleted_at).to be_present
  end
end
