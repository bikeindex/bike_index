# frozen_string_literal: true

# The fixture catalog in place of the published one
module BikebookCatalogHelpers
  FIXTURES = Rails.root.join("spec/fixtures/bikebook_catalog")

  # For the server's reads. The test cache is a file store, so a catalog cached by an earlier run goes first
  def stub_bikebook_catalog(status: 200)
    Rails.cache.clear
    WebMock.stub_request(:get, /\A#{Regexp.escape(Integrations::Bikebook::Catalog::URL)}/o).to_return do |request|
      file = FIXTURES.join(request.uri.path.delete_prefix(URI(Integrations::Bikebook::Catalog::URL).path))
      file.file? ? {status:, body: file.read} : {status: 404}
    end
  end

  # For the browser's and the server's both, with no stock photos, which render their placeholder
  def serve_bikebook_catalog(manifest_status: 200)
    stub_bikebook_catalog
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.route("#{Integrations::Bikebook::Catalog::URL}**", ->(route, request) {
        path = request.url.delete_prefix(Integrations::Bikebook::Catalog::URL)
        status = (path == "manifest.json") ? manifest_status : 200
        route.fulfill(status:, headers: {"access-control-allow-origin" => "*", "content-type" => "application/json"},
          body: (status == 200) ? FIXTURES.join(path).read : "")
      })
      playwright_page.context.route(%r{^https://bikebook\.bikeindex\.org/}, ->(route, _request) { route.abort })
    end
  end
end

RSpec.configure { it.include BikebookCatalogHelpers }
