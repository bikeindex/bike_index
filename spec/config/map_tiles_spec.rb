require "rails_helper"
require "net/http"

# Guards basemap freshness: the geography under bike-location markers changes
# slowly, so the tiles must have been refreshed within the last quarter. The
# cassette re-records itself on that interval, so CI checks the recorded
# Last-Modified offline and re-hits the live tiles once it expires.
#
# Re-record: delete spec/vcr_cassettes/maps_tiles_head.yml and run this spec
# against the live tiles.
RSpec.describe "basemap" do
  let(:max_age) { 3.months }
  let(:maps_host) { "https://maps.bikeindex.org" }

  # Grepping the JS is a little brittle, but the host is only defined there now -
  # and if the CSP drifts from it the browser blocks the tiles with no other signal.
  it "matches the host in maplibre.js and the CSP allowlist" do
    expect(Rails.root.join("app/javascript/utils/maplibre.js").read).to include(maps_host)

    directives = Rails.application.config.content_security_policy.directives
    expect(directives["img-src"]).to include(maps_host)
    expect(directives["connect-src"]).to include(maps_host)
  end

  it "has tiles refreshed within the last quarter" do
    uri = URI.parse("#{maps_host}/basemap/tiles.pmtiles")
    response = VCR.use_cassette("maps_tiles_head", match_requests_on: [:method], re_record_interval: max_age) do
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") { |http| http.head(uri.request_uri) }
    end

    last_modified = Time.zone.parse(response["last-modified"])
    expect(last_modified).to be > max_age.ago,
      "Basemap tiles are stale (last refreshed #{last_modified}). " \
      "Go to GitHub Actions and run the Upload basemap workflow."
  end
end
