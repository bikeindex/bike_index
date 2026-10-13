# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ColumnSettings::Component, type: :component do
  let(:component) do
    render_inline(described_class.new(columns: {name_cell: "Name", color_cell: "Color"}, defaults: %i[name_cell color_cell], narrow_hidden: %i[color_cell]))
  end

  it "renders a collapsed checkbox per column, marking the defaults and the narrow-hidden" do
    expect(component).to have_css("[data-ui--collapse-target='content'].tw\\:hidden\\!")
    expect(component).to have_field("Name", type: "checkbox")
    expect(component).to have_css("input[name='name_cell'][data-default='true'][data-narrow-hidden='false'][data-ui--column-settings-target='checkbox']")
    expect(component).to have_css("input[name='color_cell'][data-default='true'][data-narrow-hidden='true']")
    expect(component).to have_button("default")
  end

  describe ".data_attributes" do
    it "runs the collapse and the column settings off the storage key" do
      expect(described_class.data_attributes(storage_key: "adminThings")).to eq(controller: "ui--collapse ui--column-settings",
        "ui--collapse-storage-key-value": "adminThingsOpen",
        "ui--column-settings-storage-key-value": "adminThings")
    end

    context "orderable, with other controllers" do
      it "adds the column order controller and its drag actions" do
        attributes = described_class.data_attributes(storage_key: "adminThings", controllers: "table-multi-checkbox", orderable: true)
        expect(attributes[:controller]).to eq "table-multi-checkbox ui--collapse ui--column-settings ui--table-column-order"
        expect(attributes[:"ui--table-column-order-storage-key-value"]).to eq "adminThingsOrder"
        expect(attributes[:action]).to include("drop->ui--table-column-order#drop")
      end
    end
  end
end
