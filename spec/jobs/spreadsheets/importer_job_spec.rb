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

    context "with an unknown name" do
      it "raises" do
        expect { described_class.new.perform("bikes") }.to raise_error(ArgumentError, /Unknown importer/)
      end
    end

    context "with a transient network failure" do
      let(:url) { "#{described_class::RESOURCES_URL}/manufacturers.csv" }
      let(:csv) do
        "name,alternate_name,website,makes_frames,ebike_only,open_year,close_year,logo_url\n" \
          "Retry Bikes,,,,,,,\n"
      end
      let(:job) { described_class.new }

      before { allow(job).to receive(:sleep) } # skip the retry backoff
      after { WebMock.reset! } # these stubs are registered outside a VCR cassette

      it "retries the download, then imports" do
        WebMock.stub_request(:get, url).to_timeout.then.to_return(status: 200, body: csv)
        expect { job.perform("manufacturers") }.to change(Manufacturer, :count).by(1)
        expect(Manufacturer.friendly_find("Retry Bikes")).to be_present
      end

      it "gives up after DOWNLOAD_ATTEMPTS and raises" do
        WebMock.stub_request(:get, url).to_timeout
        expect { job.perform("manufacturers") }.to raise_error(Faraday::Error)
      end
    end
  end
end
