module BikebookCatalogHelpers
  FIXTURES = Rails.root.join("spec/fixtures/bikebook_catalog")

  # The fixture catalog in place of the published one, to the server's model pages
  def stub_bikebook_catalog(status: 200)
    Rails.cache.clear
    WebMock.stub_request(:get, /\A#{Regexp.escape(Integrations::BikeBook::Catalog::URL)}/o).to_return { |request|
      {status:, body: FIXTURES.join(request.uri.path.delete_prefix("/catalog/")).read}
    }
  end
end
