require "rails_helper"
require "aws-sdk-s3"
require "net/http"

RSpec.describe "maps rake tasks" do
  before(:all) { Rails.application.load_tasks unless Rake::Task.task_defined?("maps:upload_basemap") }

  describe "maps:upload_basemap" do
    include WebMock::API # stub_request isn't globally available in this suite

    let(:task) { Rake::Task["maps:upload_basemap"] }
    after { task.reenable }

    let(:source) { "https://build.protomaps.com/20260101.pmtiles" }
    let(:env) do
      {"R2_MAPS_ENDPOINT" => "https://r2.example.com", "R2_MAPS_ACCESS_KEY" => "key",
       "R2_MAPS_ACCESS_KEY_SECRET" => "secret", "R2_MAPS_BUCKET" => "bikeindex-maps"}
    end
    let(:s3) { Aws::S3::Client.new(stub_responses: true, region: "auto") }
    before do
      stub_const("ENV", ENV.to_hash.merge(env))
      allow(Aws::S3::Client).to receive(:new).and_return(s3)
      s3.stub_responses(:create_multipart_upload, {upload_id: "up-1"})
      s3.stub_responses(:upload_part, {etag: "\"etag-1\""})
      stub_request(:head, source).to_return(headers: {"Content-Length" => (32 * 1024 * 1024 * 3).to_s})
      stub_request(:get, source).to_return(body: "pmtiles-bytes")
    end

    it "streams the remote file into the maps bucket once confirmed" do
      allow($stdin).to receive(:gets).and_return("y\n")

      expect { task.invoke(source) }.to output(/Done: #{MAPS_HOST}\/#{MAPS_TILES_KEY}/o).to_stdout
      operations = s3.api_requests.map { |request| request[:operation_name] }
      expect(operations).to include(:create_multipart_upload, :upload_part, :complete_multipart_upload)
    end

    it "warns and aborts without uploading when not confirmed" do
      allow($stdin).to receive(:gets).and_return("n\n")

      expect { expect { task.invoke(source) }.to raise_error(SystemExit) }
        .to output(/stream .* through your current connection/).to_stderr
      expect(s3.api_requests).to be_empty
    end

    it "aborts when no source is given" do
      expect { task.invoke }.to raise_error(SystemExit)
      expect(s3.api_requests).to be_empty
    end

    context "without the R2 credentials" do
      before { stub_const("ENV", ENV.to_hash.merge(env).except("R2_MAPS_ACCESS_KEY")) }

      it "aborts without uploading" do
        expect { task.invoke(source) }.to raise_error(SystemExit)
        expect(s3.api_requests).to be_empty
      end
    end
  end

  # Guards basemap freshness: the tiles served from MAPS_HOST must have been
  # refreshed within MAPS_TILES_MAX_AGE. The cassette re-records itself on that
  # interval, so CI checks the recorded Last-Modified offline and re-hits the
  # live tiles once it expires.
  #
  # There is no cassette until maps.bikeindex.org serves the tiles, so this spec
  # fails until the basemap is uploaded - which is correct. To record it (or
  # re-record later), delete spec/vcr_cassettes/maps_tiles_head.yml and run this
  # spec against the live tiles.
  describe "basemap tiles freshness" do
    let(:re_record_interval) { MAPS_TILES_MAX_AGE }

    it "has tiles refreshed within MAPS_TILES_MAX_AGE" do
      uri = URI.parse(MAPS_TILES_URL)
      response = VCR.use_cassette("maps_tiles_head", match_requests_on: [:method], re_record_interval:) do
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.head(uri.request_uri) }
      end

      last_modified = Time.zone.parse(response["last-modified"])
      expect(last_modified).to be > MAPS_TILES_MAX_AGE.ago
    end
  end
end
