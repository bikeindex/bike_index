# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::BulkImportError::Component, type: :component do
  let(:instance) { described_class.new(bulk_import:) }
  let(:component) { render_inline(instance) }
  let(:bulk_import) { FactoryBot.build(:bulk_import, import_errors:) }
  let(:import_errors) { {} }

  context "when no errors" do
    it "does not render" do
      expect(component.text).to be_blank
    end
  end

  context "when line_errors" do
    let(:import_errors) { {"line" => [[1, "Missing serial"], [3, "Missing manufacturer"]]} }

    it "renders line errors" do
      expect(component).to have_content("Line errors:")
      expect(component).to have_content("Missing serial")
      expect(component).to have_content("Missing manufacturer")
    end
  end

  context "when file_errors" do
    let(:import_errors) { {"file" => ["Invalid CSV encoding"], "file_lines" => [""]} }

    it "renders file errors" do
      expect(component).to have_content("File errors:")
      expect(component).to have_content("Invalid CSV encoding")
    end
  end
end
