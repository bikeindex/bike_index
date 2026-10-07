# frozen_string_literal: true

# The fixture catalog in place of the published one
module BikebookCatalogHelpers
  FIXTURES = Rails.root.join("spec/fixtures/bikebook_catalog")

  # For the server's reads. The test cache is a file store, so a catalog cached by an earlier run goes first
  def stub_bikebook_catalog
    Rails.cache.delete_matched(/bikebook_catalog/)
    WebMock.stub_request(:get, /\A#{Regexp.escape(BikebookController::CATALOG_URL)}/o).to_return do |request|
      file = FIXTURES.join(request.uri.path.delete_prefix(URI(BikebookController::CATALOG_URL).path))
      file.file? ? {status: 200, body: file.read} : {status: 404}
    end
  end

  # For the browser's, with no stock photos, which render their placeholder
  def serve_bikebook_catalog(manifest_status: 200)
    page.driver.with_playwright_page do |playwright_page|
      playwright_page.context.route("#{BikebookController::CATALOG_URL}**", ->(route, request) {
        path = request.url.delete_prefix(BikebookController::CATALOG_URL)
        status = (path == "manifest.json") ? manifest_status : 200
        route.fulfill(status:, headers: {"access-control-allow-origin" => "*", "content-type" => "application/json"},
          body: (status == 200) ? FIXTURES.join(path).read : "")
      })
      playwright_page.context.route(%r{^https://bikebook\.bikeindex\.org/}, ->(route, _request) { route.abort })
    end
  end
end

RSpec.configure { it.include BikebookCatalogHelpers }
