# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::ImpoundRecordUpdateForm::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}") { render_inline(instance) }
  end
  let(:organization) { FactoryBot.create(:organization) }

  context "multi-update form" do
    let(:options) { {current_organization: organization} }

    it "renders the multi-update panel" do
      expect(component).to have_css("#makeMultiUpdate")
      expect(component).to have_css("#impoundRecordUpdateForm")
      expect(component).to have_content("Update multiple records")
      expect(component).to have_css("select#impound_record_update_kind")
      # retrieved_by_owner is the default selected kind
      expect(component).to have_css("select#impound_record_update_kind option[selected]", text: "Owner Retrieved Bike")
      # transferred_to_new_owner requires a new owner email
      expect(component).to have_css("input[name='impound_record_update[transfer_email]'][required]", visible: :all)
    end

    it "posts to the multi_update path" do
      expect(component).to have_css("form[action$='/impound_records/multi_update']")
    end
  end

  context "single impound_record" do
    let(:impound_record) { FactoryBot.create(:impound_record_with_organization, organization:) }
    let(:options) { {current_organization: organization, impound_record:} }

    it "renders the single-record update form" do
      expect(component).not_to have_css("#makeMultiUpdate")
      expect(component).to have_css("#impoundRecordUpdateForm")
      expect(component).to have_content("Update impound record")
      expect(component).to have_css("form[action$='/impound_records/#{impound_record.display_id}']")
    end
  end
end
