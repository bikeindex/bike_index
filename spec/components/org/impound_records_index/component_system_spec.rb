# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::ImpoundRecordsIndex::Component, :js, type: :system do
  let(:preview_path) { "rails/view_components/org/impound_records_index/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content "Org::ImpoundRecordsIndex::Component"
  end
end
