shared_context :geocoder_default_location do
  let(:default_location) do
    {
      latitude:  40.7143528,
      longitude: -74.0059731,
      address: 'New York, NY, USA',
      state: 'New York',
      state_code: 'NY',
      country: 'United States',
      country_code: 'US'
    }
  end
  let(:production_ip_search_result) do
    [
      {
        data: ['US', 'NY', 'New York', default_location[:latitude].to_s, default_location[:longitude].to_s],
        cache_hit: true
      }
    ]
  end
  before do
    Geocoder.configure(lookup: :test)
    Geocoder::Lookup::Test.set_default_stub([default_location.as_json])
  end
end