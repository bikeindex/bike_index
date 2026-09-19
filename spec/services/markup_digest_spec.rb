# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarkupDigest do
  describe "files" do
    it "has the current digest of its cached markup committed" do
      stale = described_class.files.filter_map do |file|
        digest = described_class.calculate(file)
        next if described_class.committed(file) == digest

        "#{file.relative_path_from(Rails.root)}: #{digest}"
      end

      expect(stale).to eq([]), "cached markup changed — run bin/update_markup_digests\n#{stale.join("\n")}"
    end
  end

  describe "markup_files" do
    let(:relative_paths) do
      described_class.markup_files(file).map { |markup| markup.relative_path_from(Rails.root).to_s }
    end

    context "a template" do
      let(:file) { Rails.root.join("app/views/bikes/_bike.html.erb") }

      it "follows the component it renders" do
        expect(relative_paths).to include("app/components/pages/search_results/bike_box/component.html.erb")
      end
    end

    context "a component that renders a partial" do
      let(:file) { Rails.root.join("app/components/pages/admin/bikes/show/messages/component.rb") }

      # The partial renders components of its own, which is the transitive step Rails'
      # digest of the same partial doesn't take
      it "follows the partial, and on into what it renders" do
        expect(relative_paths).to include("app/views/admin/notifications/_table.html.haml",
          "app/components/pages/admin/bikes/cell/component.html.erb")
      end
    end
  end
end
