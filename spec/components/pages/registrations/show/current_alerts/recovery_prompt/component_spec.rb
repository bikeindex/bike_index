# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Registrations::Show::CurrentAlerts::RecoveryPrompt::Component, type: :component do
  let(:component) { described_class.new(bike:, stolen_record:) }
  let(:bike) { FactoryBot.create(:stolen_bike) }
  let(:stolen_record) { bike.current_stolen_record }

  it "renders the recovery form, posting the token to the recovery path" do
    stolen_record.find_or_create_recovery_link_token
    render_inline(component)

    expect(page).to have_text("Mark your bike recovered!")
    expect(page).to have_text("Please tell us how you got your bike back")
    expect(page).to have_css("form[action='/bikes/#{bike.id}/recovery']")
    expect(page).to have_css("input[name='token'][value='#{stolen_record.reload.recovery_link_token}']", visible: :all)
    expect(page).to have_css("textarea[name='stolen_record[recovered_description]']")
    expect(page).to have_css("input[name='stolen_record[recovered_at]']")
    expect(page).to have_css("input[name='stolen_record[index_helped_recovery]']", visible: :all)
    expect(page).to have_css("input[name='stolen_record[can_share_recovery]']", visible: :all)
    expect(page).to have_button("Mark recovered")
  end

  context "no stolen record" do
    let(:stolen_record) { nil }

    it "does not render" do
      render_inline(component)
      expect(page.native.text).to be_blank
    end
  end
end
