class ExternalRegistryClient
  TTL_HOURS = ENV.fetch("EXTERNAL_REGISTRY_REQUEST_CACHE_TTL_HOURS", 24).to_i.hours
  TIMEOUT_SECS = ENV.fetch("EXTERNAL_REGISTRY_REQUEST_TIMEOUT", 5).to_i

  # Search external registries for the provided query string `query`.
  #
  # The set of registries searched can be customized by passing an array of
  # class names as `registries`.
  #
  # Returns an ExternalRegistryBike ActiveRecord::Relation containing any
  # records found that were successfully persisted.
  def self.search_for_bikes_with(query, registries: nil)
    registries ||= [
      StopHelingClient,
      VerlorenOfGevondenClient
    ]

    queries = [query, SerialNormalizer.new(serial: query).normalized].compact

    results =
      registries
        .flat_map { |registry| queries.map { |q| [registry, q] } }
        .map { |registry, q| Thread.new { registry.new.search(q) } }
        .flat_map(&:value)
        .compact
        .each(&:save)
        .select(&:persisted?)

    ExternalRegistryBike.where(id: results.map(&:id))
  end

  attr_accessor :base_url

  def credentials
    @credentials ||=
      self
        .class
        .to_s
        .gsub("Client", "Credential")
        .constantize
        .first
        .tap { |creds| raise CredentialsNotFoundError.new(self.class) if creds.blank? }
  end

  def conn
    @conn ||= Faraday.new(url: base_url) { |conn|
      conn.response :json, content_type: /\bjson$/
      if Rails.env.development?
        conn.use Faraday::RequestResponseLogger::Middleware,
          logger_level: :info,
          logger: Rails.logger
      end
      conn.adapter Faraday.default_adapter
      conn.options.timeout = TIMEOUT_SECS
    }
  end

  class ExternalRegistryClientError < StandardError; end

  class CredentialsNotFoundError < ExternalRegistryClientError
    def initialize(classname)
      @message = "Credentials not found for #{classname}"
      super
    end
  end
end
