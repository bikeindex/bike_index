class ExternalRegistryClient
  # ExternalRegistryClients for registries that support serial-number searches.
  def self.all
    [
      VerlorenOfGevondenClient,
      StopHelingClient,
    ]
  end

  # Search external registries for the provided `query.`
  #
  # The set of registries searched can be customized by passing an array of
  # class names as `registries`.
  #
  # Returns an ExternalRegistryBike ActiveRecord::Relation containing any
  # records found that were successfully persisted.
  def self.search_for_bikes_with(query, registries: all)
    results =
      registries
        .map { |registry| Thread.new { registry.new.search(query) } }
        .map(&:value)
        .flatten
        .compact

    ExternalRegistryBike.where(id: results.map(&:id))
  end
end
