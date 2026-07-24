require "rails_helper"
require "net/http"

# Guards basemap freshness: the tiles served from MAPS_HOST must have been
# refreshed within the last quarter. The cassette re-records itself on that
# interval, so CI checks the recorded Last-Modified offline and re-hits the
# live tiles once it expires.
#
# There is no cassette until maps.bikeindex.org serves the tiles, so this spec
# fails until the basemap is uploaded - which is correct. To record it (or
# re-record later), delete spec/vcr_cassettes/maps_tiles_head.yml and run this
# spec against the live tiles.
RSpec.describe "basemap tiles freshness" do
  let(:max_age) { 3.months }

  it "has tiles refreshed within the last quarter" do
    uri = URI.parse(MAPS_TILES_URL)
    response = VCR.use_cassette("maps_tiles_head", match_requests_on: [:method], re_record_interval: max_age) do
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.head(uri.request_uri) }
    end

    last_modified = Time.zone.parse(response["last-modified"])
    expect(last_modified).to be > max_age.ago
  end
end
