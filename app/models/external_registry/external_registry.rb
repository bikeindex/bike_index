module ExternalRegistry
  class ExternalRegistry
    def self.all
      [
        VerlorenOfGevondenClient,
        StopHelingClient,
      ]
    end

    def self.search_for_bikes_with(serial_number:, registries: all)
      results =
        registries
          .map { |registry| Thread.new { registry.new.search(serial_number) } }
          .map(&:value)
          .flatten
          .compact

      ExternalRegistryBike.where(id: results.map(&:id))
    end
  end
end
