# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::Bikebook::MarketVariants do
  describe "expand" do
    let(:home) do
      {"id" => "m/acme/2025/one", "markets" => ["US"], "description" => "Fast", "years" => {"2025" => {"url" => "us"}, "2026" => {"url" => "us"}},
       "wheels" => [{"position" => "front", "bsd" => 406}, {"position" => "rear", "bsd" => 406}],
       "motors" => [{"rated_power" => 750, "operating_modes" => [{"mode" => "assist", "max_speed" => 45}, {"mode" => "throttle", "max_speed" => 32}]}]}
    end
    let(:changes) do
      {"markets" => ["CA"], "description" => nil, "years" => {"2025" => {"url" => "ca"}, "2026" => false},
       "wheels" => {"rear 406" => {"bsd" => 507}},
       "motors" => {"0" => {"rated_power" => 500, "operating_modes" => {"assist" => {"max_speed" => 32}}}}}
    end

    it "puts each market's model beside its home market's, and leaves a record without any as it is" do
      other = {"id" => "m/acme/2025/two", "markets" => ["US"]}
      models = {"m/acme/2025/one" => home.merge("market_variants" => {"CA" => changes}), "m/acme/2025/two" => other}

      expect(described_class.expand(models)).to eq({
        "m/acme/2025/one" => home,
        "m/acme/2025/one_ca" => {"id" => "m/acme/2025/one_ca", "markets" => ["CA"], "years" => {"2025" => {"url" => "ca"}},
                                 "wheels" => [{"position" => "front", "bsd" => 406}, {"position" => "rear", "bsd" => 507}],
                                 "motors" => [{"rated_power" => 500, "operating_modes" => [{"mode" => "assist", "max_speed" => 32}, {"mode" => "throttle", "max_speed" => 32}]}]},
        "m/acme/2025/two" => other
      })
    end
  end
end
