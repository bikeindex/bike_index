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

  let(:geo_hash) do
    {
      data: ['US', 'NY', 'New York', default_location[:latitude].to_s, default_location[:longitude].to_s],
      cache_hit: true
    }
  end
  let(:legacy_production_ip_search_result) { [geo_hash] }

  let(:production_ip_search_result) { [OpenStruct.new(geo_hash)] }

  let(:bounding_box) { [39.989124784445764, -74.96065051723293, 41.43644261555424, -73.05123208276707] }

  before do
    Geocoder.configure(lookup: :test)
    Geocoder::Lookup::Test.set_default_stub([default_location.as_json])
    allow(Geocoder::Calculations).to receive(:bounding_box) { bounding_box }
  end
end
