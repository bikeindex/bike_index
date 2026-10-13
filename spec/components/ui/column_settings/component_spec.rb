# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ColumnSettings::Component, type: :component do
  let(:component) { render_inline(described_class.new(columns: {name_cell: "Name", color_cell: "Color"}, defaults: %i[name_cell])) }

  it "renders a collapsed checkbox per column, marking the defaults" do
    expect(component).to have_css("[data-ui--collapse-target='content'].tw\\:hidden\\!")
    expect(component).to have_field("Name", type: "checkbox")
    expect(component).to have_css("input[name='name_cell'][data-default='true'][data-ui--column-settings-target='checkbox']")
    expect(component).to have_css("input[name='color_cell'][data-default='false']")
    expect(component).to have_button("default")
  end

  describe ".data_attributes" do
    it "runs the collapse and the column settings off the storage key" do
      attributes = described_class.data_attributes(storage_key: "adminThings", narrow_hidden_columns: %w[photo_cell])
      expect(attributes).to eq(controller: "ui--collapse ui--column-settings",
        "ui--collapse-storage-key-value": "adminThingsOpen",
        "ui--column-settings-storage-key-value": "adminThings",
        "ui--column-settings-narrow-hidden-columns-value": %w[photo_cell])
    end
  end
end
