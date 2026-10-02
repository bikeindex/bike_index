# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::ImpoundRecords::Index::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}") { render_inline(instance) }
  end
  let(:organization) { FactoryBot.create(:organization) }
  let(:pagy) { Pagy::Offset.new(count: 0, limit: 25, page: 1) }
  let(:options) do
    {
      pagy:,
      impound_records: ImpoundRecord.none,
      current_organization: organization,
      per_page: 25,
      sort_state: ComponentStructs::SortState.new(sort: "created_at", direction: "desc")
    }
  end

  it "renders the results card, with the multi-update toggle and its form" do
    expect(component).to have_content(/0\s+matches/)
    expect(component).to have_button("Update multiple records")
    expect(component).to have_button("Column settings")
    expect(component).to have_css("form##{Pages::Org::ImpoundRecords::UpdateForm::Component::MULTI_FORM_ID}", visible: :all)
    expect(component).to have_link("Cards")
  end
end
