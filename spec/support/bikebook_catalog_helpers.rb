# frozen_string_literal: true

# The fixture catalog in place of the published one. Its kit is at the 1.0.0 vehicle schema and its models a mix, as
# a catalog part way through migrating them publishes: Specialized's 2025 at 0.28.0, Segway's before 0.28.0
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

  # The catalog as it is once it publishes again: a new vocabulary, and Segway's 2025 block with a new description
  def stub_bikebook_catalog_update
    url = Integrations::Bikebook::Catalog::URL
    block = JSON.parse(FIXTURES.join("models/segway/2025.json").read)
    block["models"]["m/segway/2025/gt3_pro"]["description"] = "Updated"
    WebMock.stub_request(:get, "#{url}models/segway/2025.v2.json").to_return(body: block.to_json)
    WebMock.stub_request(:get, "#{url}vocabulary.v2.json").to_return(body: FIXTURES.join("vocabulary.json").read)
    manifest = JSON.parse(FIXTURES.join(Integrations::Bikebook::Catalog::MANIFEST).read)
    manifest = manifest.merge("vocabulary" => "vocabulary.v2.json", "blocks" => manifest["blocks"].merge("segway/2025" => "models/segway/2025.v2.json"))
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
