require "rails_helper"

RSpec.describe Spreadsheets::ImporterJob, type: :job do
  it "is the correct queue" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority"
  end

  describe "perform" do
    let(:csvs) do
      {
        # Müller exercises multibyte UTF-8; Faraday hands back ASCII-8BIT bodies
        "manufacturers" => "name,alternate_name,website,makes_frames,ebike_only,open_year,close_year,logo_url\n" \
          "Müller,,https://example.com,true,false,2001,,\n",
        "primary_activities" => "flavor,families\nBike Polo,\n",
        "components" => "name,secondary_name,has_multiple_locations,group\nWheel,,true,Wheels\n"
      }
    end
    before do
      allow_any_instance_of(described_class).to receive(:download) { |_, url|
        csvs.fetch(File.basename(url, ".csv")).dup.force_encoding("ASCII-8BIT")
      }
    end

    context "with no args" do
      it "imports every spreadsheet" do
        described_class.new.perform
        expect(Manufacturer.friendly_find("Müller")).to be_present
        expect(PrimaryActivity.friendly_find("Bike Polo")).to be_present
        expect(Ctype.friendly_find("Wheel")).to be_present
      end
    end

    context "with a name" do
      it "imports only the named spreadsheet" do
        expect { described_class.new.perform("manufacturers") }.to change(Manufacturer, :count).by 1
        expect(Ctype.friendly_find("Wheel")).to be_blank
      end
    end
  end
end
