module ExternalRegistries
  class ExternalRegistrySearch
    attr_accessor :registries

    def self.by_serial(serial_number)
      new.by_serial(serial_number)
    end

    def initialize(registries = nil)
      self.registries = registries || {
        stop_heling: StopHelingClient.new,
        verloren_of_gevonden: VerlorenOfGevondenClient.new,
      }
    end

    def by_serial(serial_number)
      registries
        .map { |_, reg| Thread.new { reg.search(serial_number) } }
        .map(&:value)
        .flatten
        .compact
    end
  end
end
