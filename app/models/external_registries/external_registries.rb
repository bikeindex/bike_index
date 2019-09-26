module ExternalRegistries::ExternalRegistries
  def create_all
    registries = [
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
    ExternalRegistry.create(registries)
  end

  def verloren_of_gevonden
    find_by(name: "verlorenofgevonden.nl")
  end

  def stop_heling
    find_by(name: "stopheling.nl")
  end
end
