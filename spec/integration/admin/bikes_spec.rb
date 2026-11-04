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
  it "asks before deleting and un-deleting a bike, and does each only once confirmed" do
    visit "/admin/bikes/#{bike.id}/edit"

    expect(dismiss_confirm { click_link "Delete bike" }).to eq "Are you sure?"
    expect(page).to have_current_path("/admin/bikes/#{bike.id}/edit")
    expect(bike.reload.deleted_at).to be_nil

    accept_confirm { click_link "Delete bike" }

    expect(page).to have_content("Bike deleted!")
    expect(bike.reload.deleted_at).to be_present

    visit "/admin/bikes/#{bike.id}/edit"

    expect(dismiss_confirm { click_link "Un-delete bike" }).to eq "Are you sure?"
    expect(bike.reload.deleted_at).to be_present

    accept_confirm { click_link "Un-delete bike" }

    expect(page).to have_content("Bike un-deleted!")
    expect(page).to have_no_link("Un-delete bike")
    expect(bike.reload.deleted_at).to be_nil
  end
end
