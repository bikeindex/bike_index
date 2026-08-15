# frozen_string_literal: true

require "rails_helper"

RSpec.describe HtmlSafeTranslation do
  describe "translate" do
    let(:scope) { [:components, :org, :bulk_import_error] }
    subject(:result) { described_class.translate(key, scope:, **kwargs) }

    context "a plain key" do
      let(:key) { ".organizations" }
      let(:kwargs) { {} }

      it "returns the translation, not marked html_safe" do
        expect(result).to eq "organizations"
        expect(result).to_not be_html_safe
      end
    end

    context "an _html key" do
      let(:key) { ".ascend_unprocessable_html" }
      let(:kwargs) { {ascend_name: "Sweet Bikes"} }

      it "marks the translation html_safe" do
        expect(result).to be_html_safe
        expect(result).to match "Sweet Bikes"
      end

      context "with a value containing markup" do
        let(:kwargs) { {ascend_name: "<script>alert(1)</script>"} }

        it "escapes the interpolated value" do
          expect(result).to_not include "<script>"
          expect(result).to include "&lt;script&gt;"
        end
      end

      context "with an html_safe value" do
        let(:kwargs) { {ascend_name: "<em>Sweet Bikes</em>".html_safe} }

        it "passes it through untouched" do
          expect(result).to include "<em>Sweet Bikes</em>"
        end
      end
    end

    context "a nil scope segment" do
      let(:key) { ".organizations" }
      let(:scope) { [:components, nil, :org, :bulk_import_error] }
      let(:kwargs) { {} }

      it "compacts it away" do
        expect(result).to eq "organizations"
      end
    end

    # count drives pluralization, so it can't be stringified on its way through
    context "an _html key with a numeric count" do
      let(:scope) { [:components, :registrations, :show, :org_top_actions, :wrapper] }
      let(:key) { ".view_notifications_resolved_html" }
      let(:kwargs) { {count: 2} }

      it "leaves count numeric" do
        expect(result).to be_html_safe
        expect(result).to match "2"
      end
    end
  end
end
