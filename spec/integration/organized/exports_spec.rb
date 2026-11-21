# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organized exports", :js, type: :system do
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[csv_exports avery_export]) }
  let(:user) { FactoryBot.create(:organization_admin, organization:) }
  let!(:claimed_sticker) { FactoryBot.create(:bike_sticker_claimed, organization:, code: "A1111") }

  before do
    stub_const("ENV", ENV.to_hash.merge("AVERY_EXPORT_URL" => "/news?mergeDataURL="))
    sign_in(user)
  end

  it "shows the fields each kind of export asks for, and reloads an Avery export through to its file" do
    visit new_organization_export_path(organization_id: organization.to_param)
    wait_for_stimulus("org--export-form")

    expect(page).to have_no_field("Registered after")
    click_button "Set after time"
    expect(page).to have_field("Registered after", with: /T00:00\z/)
    expect(page).to have_no_button("Set after time")
    click_button "remove"
    expect(page).to have_button("Set after time")
    expect(page).to have_no_field("Registered after")

    expect(page).to have_no_field("Bikes to export")
    click_button "Add specific bikes to export"
    expect(page).to have_field("Bikes to export")
    expect(page).to have_checked_field("Only include specific bikes")
    expect(page).to have_no_button("Set before time")
    uncheck "Only include specific bikes"
    expect(page).to have_button("Set before time")
    expect(page).to have_no_button("Add specific bikes to export")

    expect(page).to have_no_field("Initial Sticker #")
    expect(page).to have_select("export_file_format")
    check "Avery Label Export"
    expect(page).to have_field("Initial Sticker #")
    expect(page).to have_no_select("export_file_format")
    uncheck "Avery Label Export"
    expect(page).to have_no_field("Initial Sticker #")
    expect(page).to have_select("export_file_format")

    check "Avery Label Export"
    fill_in "Initial Sticker #", with: claimed_sticker.code
    click_button "Create export"

    # Re-rendered from create, which starts with the fields that apply to what was submitted
    expect(page).to have_content("already been assigned")
    expect(page).to have_checked_field("Avery Label Export")
    expect(page).to have_field("Initial Sticker #")
    expect(page).to have_no_select("export_file_format")

    fill_in "Initial Sticker #", with: ""
    expect {
      click_button "Create export"
      expect(page).to have_current_path(/avery_redirect=true/)
    }.to change(Export, :count).by 1
    export = Export.last
    expect(export.avery_export?).to be_truthy
    expect(export.start_at).to be_blank

    OrganizationExportJob.drain
    expect(page).to have_current_path(/mergeDataURL=/, wait: 10)
  end
end
