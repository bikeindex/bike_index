require "rails_helper"

RSpec.describe Spreadsheets::ImporterJob, type: :job do
  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    context "with no args" do
      it "imports every spreadsheet" do
        VCR.use_cassette("Spreadsheets_ImporterJob") do
          described_class.new.perform
        end
        # Müller exercises multibyte UTF-8 round-tripping through the download
        expect(Manufacturer.friendly_find("Riese & Müller")).to be_present
        expect(PrimaryActivity.count).to be > 0
        expect(Ctype.friendly_find("Wheel")).to be_present
      end
    end

    context "with a name" do
      it "imports only the named spreadsheet" do
        VCR.use_cassette("Spreadsheets_ImporterJob-components") do
          expect { described_class.new.perform("components") }
            .to change(Ctype, :count)
            .and change(Manufacturer, :count).by(0)
            .and change(PrimaryActivity, :count).by(0)
        end
      end
    end
  end
end
