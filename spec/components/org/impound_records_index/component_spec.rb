# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::ImpoundRecordsIndex::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {per_page:, interpreted_params:, pagy:, impound_records:} }
  let(:per_page) { nil }
  let(:interpreted_params) { nil }
  let(:pagy) { nil }
  let(:impound_records) { nil }

  it "renders" do
    expect(component).to have_css("div")
  end
end
