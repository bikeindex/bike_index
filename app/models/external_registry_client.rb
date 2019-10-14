class ExternalRegistryClient
  TTL_HOURS = ENV.fetch("EXTERNAL_REGISTRY_REQUEST_CACHE_TTL_HOURS", 24).to_i.hours
  TIMEOUT_SECS = ENV.fetch("EXTERNAL_REGISTRY_REQUEST_TIMEOUT", 5).to_i

  # Search external registries for the provided `query.`
  #
  # The set of registries searched can be customized by passing an array of
  # class names as `registries`.
  #
  # Returns an ExternalRegistryBike ActiveRecord::Relation containing any
  # records found that were successfully persisted.
  def self.search_for_bikes_with(query, registries: nil)
    registries ||= [
      VerlorenOfGevondenClient,
      StopHelingClient,
    ]

    results =
      registries
        .map { |registry| Thread.new { registry.new.search(query) } }
        .map(&:value)
        .flatten
        .compact

    ExternalRegistryBike.where(id: results.map(&:id))
  end

  attr_accessor :base_url

  def registry_name
    self.class.to_s.split("::").last.to_s.chomp("Client")
  end

  def credentials
    @credentials ||= "ExternalRegistryCredential::#{registry_name}Credential".constantize.first
  end

  def conn
    @conn ||= Faraday.new(url: self.base_url) do |conn|
      conn.response :json, content_type: /\bjson$/
      conn.use Faraday::RequestResponseLogger::Middleware,
               logger_level: :info,
               logger: Rails.logger if Rails.env.development?
      conn.adapter Faraday.default_adapter
      conn.options.timeout = TIMEOUT_SECS
    end
  end
end
