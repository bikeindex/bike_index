# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::BulkImportError::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {bulk_import:, short_display:, in_admin:} }
  let(:in_admin) { false }
  let(:short_display) { false }
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

  describe "short_text" do
    let(:short_display) { true }
    let(:component_text) { whitespace_normalized_body_text(component.to_html) }

    context "when line_errors" do
      let(:import_errors) { {"line" => lines} }
      let(:lines) { [[2, ["Association error 62049780564 is out of range for ActiveModel::Type::Integer with limit 4 bytes"]]] }

      it "renders Line" do
        expect(component_text).to eq("1 Line error")
      end

      context "with multiple line errors" do
        let(:lines) do
          [[2, ["Owner email invalid format"]],
            [3, ["Owner email invalid format"]],
            [4, ["Owner email invalid format"]],
            [5, ["Owner email invalid format"]]]
        end
        it "renders Line" do
          expect(component_text).to eq("4 Line errors")
        end
      end
    end

    context "when file_errors" do
      let(:import_errors) { {"file" => file_error, "file_lines" => [""]} }
      let(:file_error) { ["\"\\xE2\" from ASCII-8BIT to UTF-8"] }

      it "renders File" do
        expect(component_text).to eq("File")
      end

      context "invalid file extension" do
        let(:file_error) { ["Invalid file extension, must be .csv or .tsv"] }
        it "renders File" do
          expect(component_text).to eq(file_error.first)
        end
      end
    end

    context "when ascend_errors" do
      let(:import_errors) { {"ascend" => ["Unable to find an Organization with ascend_name = XXX_yyy"]} }

      it "renders Ascend" do
        expect(component_text).to eq("Unknown Ascend name")
      end
    end
  end
end
