# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationComponent do
  describe ".markup_files" do
    let(:files) { described_class.markup_files.map { |file| file.relative_path_from(Rails.root).to_s } }

    it "covers every component, without the previews that render outside cache blocks" do
      expect(files).to include("app/components/ui/table/component.html.erb")
      expect(files).to include("app/components/page_block/footer/component.html.erb")
      expect(files).to_not include("app/components/ui/table/component_preview.rb")
    end

    it "adds extra_markup" do
      expect(described_class.markup_files("app/views/admin/users/_table.html.erb").map(&:to_s))
        .to include(Rails.root.join("app/views/admin/users/_table.html.erb").to_s)
    end

    it "raises rather than covering nothing" do
      expect { described_class.markup_files("app/components/tabel/**/*") }.to raise_error(/No cached markup/)
    end
  end

  describe ".markup_digest" do
    it "is constant when caching is off, so nothing pays to digest markup that can't go stale" do
      expect(described_class.markup_digest).to eq "nocache"
    end

    context "with caching", :caching do
      include_context :caching_basic

      it "digests the markup it covers" do
        expect(described_class.markup_digest).to match(/\A\h{12}\z/)
        expect(described_class.markup_digest("app/views/admin/users/_table.html.erb"))
          .to_not eq described_class.markup_digest
      end
    end
  end
end
