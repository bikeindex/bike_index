# frozen_string_literal: true

# Points ActiveStorage at the bikeindex-test R2 bucket, for the specs that upload for real
# rather than to the Disk service - the only way to exercise a presigned, cross-origin PUT.
# Needs R2_TEST_* (in .env.test locally, repo secrets in CI).
RSpec.shared_context :cloudflare_test_storage do
  # example.com is .env's placeholder: it signs, but there's no bucket behind it. Only the runs
  # without secrets may skip - anywhere else the credentials went missing.
  before do
    next unless ENV["R2_TEST_ENDPOINT"].to_s.include?("example.com")
    raise "R2_TEST_* credentials are missing" if ENV["CI_WITHOUT_SECRETS"] == "false"
    skip "no R2_TEST_* credentials"
  end

  # service is a class_attribute, so the Capybara server thread picks this up too. VCR blocks
  # un-cassetted http, and a browser's PUT can't be cassetted anyway - it isn't a ruby request.
  around do |example|
    default_service = ActiveStorage::Blob.service
    ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:cloudflare_test)
    without_http_stubbing { example.run }
  ensure
    ActiveStorage::Blob.service = default_service
  end

  # However far the example got, don't leave objects in the bucket. `delete` rather than
  # `purge`: an attached blob's destroy hits a foreign key, which purge rescues, so it never
  # reaches storage - the rows go with the transaction anyway.
  after do
    without_http_stubbing do
      ActiveStorage::Blob.where(service_name: "cloudflare_test").each(&:delete)
    end
  end

  # WebMock.disable!/enable! rather than allow_net_connect!, which would restore a different
  # config than VCR installed and leak that to every later example
  def without_http_stubbing
    VCR.turned_off(ignore_cassettes: true) do
      WebMock.disable!
      # aws-sdk pools its Net::HTTP sessions, and WebMock swaps the class, not live instances
      Seahorse::Client::NetHttp::ConnectionPool.pools.each(&:empty!)
      yield
    ensure
      WebMock.enable!
    end
  end
end
