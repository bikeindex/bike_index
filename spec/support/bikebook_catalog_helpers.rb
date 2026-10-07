# frozen_string_literal: true

module BikebookCatalogHelpers
  # The fixture catalog in place of the published one, for the server's reads of it.
  # The test cache is a file store, so a catalog cached by an earlier run goes first
  def stub_bikebook_catalog
    Rails.cache.delete_matched(/ebike_rules/)
    fixtures = Rails.root.join("spec/fixtures/bikebook_catalog")
    WebMock.stub_request(:get, %r{\Ahttps://bikebook-catalog\.bikeindex\.org/catalog/}).to_return do |request|
      file = fixtures.join(request.uri.path.delete_prefix("/catalog/"))
      file.file? ? {status: 200, body: file.read} : {status: 404}
    end
  end
end

RSpec.configure { it.include BikebookCatalogHelpers }
