RSpec.shared_context :geocoder_default_location do
  let(:default_location) do
    {
      latitude: 40.7143528,
      longitude: -74.0059731,
      address: "New York, NY, USA",
      formatted_address: "278 Broadway, New York, NY 10007, USA",
      formatted_address_no_country: "278 Broadway, New York, NY 10007",
      street_address: "278 Broadway",
      city: "New York",
      state: "New York",
      state_code: "NY",
      neighborhood: "Tribeca",
      country: "United States",
      country_code: "US",
      postal_code: "10007"
    }
  end

  let(:default_location_registration_address) do
    # when passed through the registration address method, default location comes out like this
    {
      street: "278 Broadway",
      city: "New York",
      state: "NY",
      zipcode: "10007",
      country: "US",
      latitude: 40.7143528,
      longitude: -74.0059731
    }.as_json
  end

  let(:default_location_registration_address_new) do
    Geocodeable.new_address_hash(default_location_registration_address)
  end

  let(:default_location_coordinates) { default_location.slice(:latitude, :longitude).values }

  let(:geo_hash) do
    {
      data: ["US", "NY", "New York", default_location[:latitude].to_s, default_location[:longitude].to_s],
      cache_hit: true
    }
  end

  let(:bounding_box) do
    [
      39.989124784445764,
      -74.96065051723293,
      41.43644261555424,
      -73.05123208276707
    ]
  end

  before do
    Geocoder.configure(lookup: :test, ip_lookup: :test, api_key: ENV["GOOGLE_GEOCODER"])
    Geocoder::Lookup::Test.set_default_stub([default_location.as_json])
  end
end

RSpec.shared_context :geocoder_stubbed_bounding_box do
  before do
    allow(Geocoder::Calculations).to receive(:bounding_box) { bounding_box }
  end
end

RSpec.shared_context :geocoder_real do
  before do
    Geocoder.configure(
      lookup: :google, use_https: true, api_key: ENV["GOOGLE_GEOCODER"],
      ip_lookup: :maxmind, maxmind: {service: :city, api_key: ENV["MAXMIND_KEY"]}
    )
  end

  after do
    Geocoder.configure(lookup: :test, ip_lookup: :test)
  end
end
