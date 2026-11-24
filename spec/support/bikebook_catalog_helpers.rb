# frozen_string_literal: true

# The fixture catalog in place of the published one: its blocks' models' published records, and an index of their
# published rows beside cases of its own, which regenerating it from the published catalog would drop: the Specialized
# 2025 models and the Reactive Adaptations Nuke only the index lists, Kris Holm's unicycles sold in Canada but for
# kh24-us, and the Segway GT3 Pro sold in the UAE and China
module BikebookCatalogHelpers
  FIXTURES = Rails.root.join("spec/fixtures/bikebook_catalog")

  # For the server's reads. The test cache is a file store, so a catalog cached by an earlier run goes first, as does
  # what an earlier example read outside a request
  def stub_bikebook_catalog(status: 200)
    Rails.cache.clear
    Integrations::Bikebook::Catalog::Reads.reset
    WebMock.stub_request(:get, /\A#{Regexp.escape(Integrations::Bikebook::Catalog::URL)}/o).to_return do |request|
      file = FIXTURES.join(request.uri.path.delete_prefix(URI(Integrations::Bikebook::Catalog::URL).path))
      file.file? ? {status:, body: file.read} : {status: 404}
    end
  end

  # The catalog as it is once it publishes again: a new vocabulary, Segway's 2025 block with a new description, and a
  # schema viewer counting 12,345,678 models with a manufacturer
  def stub_bikebook_catalog_update
    url = Integrations::Bikebook::Catalog::URL
    block = JSON.parse(FIXTURES.join("models/segway/2025.json").read)
    block["models"]["m/segway/2025/gt3-pro"]["description"] = "Updated"
    WebMock.stub_request(:get, "#{url}models/segway/2025.v2.json").to_return(body: block.to_json)
    WebMock.stub_request(:get, "#{url}vocabulary.v2.json").to_return(body: FIXTURES.join("vocabulary.json").read)
    viewer = JSON.parse(FIXTURES.join("schema_viewer.json").read)
    viewer["documents"]["vehicle_model"]["fields"]["manufacturer"]["models_count"] = 12_345_678
    WebMock.stub_request(:get, "#{url}schema_viewer.v2.json").to_return(body: viewer.to_json)
    manifest = JSON.parse(FIXTURES.join(Integrations::Bikebook::Catalog::MANIFEST).read)
    manifest = manifest.merge("vocabulary" => "vocabulary.v2.json", "schema_viewer" => "schema_viewer.v2.json",
      "blocks" => manifest["blocks"].merge("segway/2025" => "models/segway/2025.v2.json"))
    WebMock.stub_request(:get, "#{url}#{Integrations::Bikebook::Catalog::MANIFEST}").to_return(body: manifest.to_json)
  end

  # For the browser's and the server's both, with no stock photos, which render their placeholder
  def serve_bikebook_catalog(manifest_status: 200)
    stub_bikebook_catalog
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.route("#{Integrations::Bikebook::Catalog::URL}**", ->(route, request) {
        path = request.url.delete_prefix(Integrations::Bikebook::Catalog::URL)
        status = (path == Integrations::Bikebook::Catalog::MANIFEST) ? manifest_status : 200
        route.fulfill(status:, headers: {"access-control-allow-origin" => "*", "content-type" => "application/json"},
          body: (status == 200) ? FIXTURES.join(path).read : "")
      })
      playwright_page.context.route(%r{^https://bikebook\.bikeindex\.org/}, ->(route, _request) { route.abort })
    end
  end

  # Holds each request for a catalog file matching `pattern`, the queue they're answered from
  def hold_bikebook_catalog_file(pattern)
    Queue.new.tap do |held|
      page.driver.with_playwright_page do |playwright_page|
        playwright_page.context.route("#{Integrations::Bikebook::Catalog::URL}#{pattern}", ->(route, _request) { held << route })
      end
    end
  end
end

RSpec.configure { it.include BikebookCatalogHelpers }

# Unless a spec stubs it, the catalog 404s, and a cassette never records it. By host, as WebMock's URI carries the port
catalog_host = URI(Integrations::Bikebook::Catalog::URL).host
VCR.configure { |config| config.ignore_request { URI(it.uri).host == catalog_host } }
WebMock.globally_stub_request(:after_local_stubs) { |request| {status: 404} if request.uri.host == catalog_host }
