module ExternalRegistries::ExternalRegistries
  def registries_attrs
    [
      {
        name: "verlorenofgevonden.nl",
        url: "https://verlorenofgevonden.nl",
        client_class: "VerlorenOfGevondenClient",
        country_id: Country.netherlands.id,

      },
      {
        name: "stopheling.nl",
        url: "https://www.stopheling.nl",
        client_class: "StopHelingClient",
        country_id: Country.netherlands.id,
      },
    ]
  end

  def create_all
    registries_attrs.map.with_index(1) do |registry_attrs, i|
      record = ExternalRegistry.find_or_create_by(registry_attrs)
      yield(record, i) if block_given?
      record
    end
  end

  def verloren_of_gevonden
    where(name: "verlorenofgevonden.nl").first
  end

  def stop_heling
    where(name: "stopheling.nl").first
  end
end
