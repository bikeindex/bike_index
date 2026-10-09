# frozen_string_literal: true

require "rails_helper"

RSpec.describe EbikeRuleServices::Evaluator do
  before { stub_bikebook_catalog }

  let(:attributes) do
    {bikebook_id: "m/x/2025/y", manufacturer_name: "X", model: "Y", first_year: 2025, e_bike_class: 1, class_unknown: false, e_vehicle_classifications: [],
     watts: 250, top_assist_mph: 20, throttle: false, throttle_mph: nil, ul2849: :unknown, ul2271: :unknown, photo_url: nil}
  end
  let(:bike) { EbikeRuleServices::Bike.new(**attributes) }
  let(:abbreviation) { "IN" }
  let(:law) { EbikeRuleServices::StateLaws.find(abbreviation) }
  let(:rules) { described_class.rules(law:, bike:) }
  let(:statuses) { rules.to_h { [it[:id], it[:status]] } }

  it "passes a Class 1 bike in Indiana" do
    expect(statuses).to eq(classes: :pass, power: :pass, speed: :pass, throttle: :pass)
    expect(described_class.verdict(rules)).to eq :green
  end

  context "with a bike entered by hand as faster than Class 3" do
    let(:bike) { EbikeRuleServices::Bike.manual(top_mph: 29, watts: nil, throttle: false) }

    it "fails a state capping assist at 28 mph" do
      expect(rules.find { it[:id] == :speed }).to include(status: :fail, note: :speed_past_cap, args: {past: 28, cap: 28})
    end

    context "in a state with a higher cap" do
      let(:law) { EbikeRuleServices::StateLaws.find("IN").merge(mph: 30) }

      it "leaves the speed to check" do
        expect(rules.find { it[:id] == :speed }).to include(status: :check, note: :speed_past, args: {past: 28, cap: 30})
      end
    end
  end

  context "with a Class 3 bike with a throttle in Colorado" do
    let(:abbreviation) { "CO" }
    let(:attributes) { super().merge(e_bike_class: 3, top_assist_mph: 28, throttle: true) }

    it "is legal, with its throttle to check" do
      expect(statuses).to eq(classes: :pass, power: :pass, speed: :pass, throttle: :check)
      expect(described_class.verdict(rules)).to eq :yellow
    end

    context "whose throttle the catalog records stopping at 20 mph" do
      let(:attributes) { super().merge(throttle_mph: 20) }

      it "passes its throttle" do
        expect(rules.find { it[:id] == :throttle }).to include(status: :pass, note: :class_3_throttle_within, args: {mph: 20})
        expect(described_class.verdict(rules)).to eq :green
      end
    end

    context "whose throttle the catalog records past 20 mph" do
      let(:attributes) { super().merge(throttle_mph: 28) }

      it "fails its throttle" do
        expect(rules.find { it[:id] == :throttle }).to include(status: :fail, note: :class_3_throttle_over, args: {mph: 28})
      end
    end
  end

  context "with a Class 3 bike in California" do
    let(:abbreviation) { "CA" }
    let(:attributes) { super().merge(e_bike_class: 3, watts: 750, top_assist_mph: 28) }

    it "checks it against California's law as it does any three-class state's" do
      expect(statuses).to eq(classes: :pass, power: :pass, speed: :pass, throttle: :pass)
      expect(described_class.verdict(rules)).to eq :green
    end
  end

  context "with a bike that is both Class 2 and Class 3" do
    let(:attributes) do
      super().merge(e_bike_class: 3, e_vehicle_classifications: %w[evc/us/class_2 evc/us/class_3], top_assist_mph: 28, throttle: true, throttle_mph: 20)
    end

    it "recognizes both" do
      expect(rules.first).to include(status: :pass, note: :class_recognized, args: {e_bike_classes: [2, 3]})
    end

    context "under a law without Class 2" do
      let(:law) { EbikeRuleServices::StateLaws.find("IN").merge(classes: [1, 3]) }

      it "fails on the class it lacks" do
        expect(rules.first).to include(status: :fail, note: :class_not_recognized, args: {e_bike_classes: [2]})
      end
    end
  end

  context "with a law whose limits aren't yet in force" do
    let(:law) { EbikeRuleServices::StateLaws.find("NC", today: Date.new(2026, 11, 30)) }
    let(:attributes) { super().merge(e_bike_class: 3, watts: 1_000, top_assist_mph: 28) }

    it "says when they take effect rather than checking against them, and points to today's rules" do
      expect(statuses).to eq(classes: :check, power: :info, speed: :info, throttle: :pass)
      expect(rules.first).to include(note: :classes_start_on, args: {date: Date.new(2026, 12, 1)})
      expect(rules[1..2]).to all(include(note: :limits_start_on, args: {date: Date.new(2026, 12, 1)}))
      expect(described_class.verdict(rules)).to eq :yellow
    end
  end

  context "with a motor over the cap and a Class 1 throttle" do
    let(:attributes) { super().merge(watts: 1_000, throttle: true) }

    it "fails" do
      expect(statuses.select { |_id, status| status == :fail }.keys).to eq %i[power throttle]
      expect(rules.find { it[:id] == :power }).to include(note: :watts_over_cap, args: {watts: 1_000, cap: 750})
      expect(described_class.verdict(rules)).to eq :red
    end
  end

  context "in a state with its own limits rather than the three classes" do
    let(:abbreviation) { "NY" }
    let(:attributes) { super().merge(e_bike_class: 3, top_assist_mph: 28) }

    it "fails on its speed cap" do
      expect(statuses).to include(classes: :info)
      expect(rules.find { it[:id] == :speed }).to include(status: :fail, note: :speed_over_cap, args: {mph: 28, cap: 25})
    end
  end

  context "with a throttle in a state that allows none" do
    let(:abbreviation) { "NJ" }
    let(:attributes) { super().merge(e_bike_class: 2, throttle: true) }

    it "fails on the throttle" do
      expect(rules.find { it[:id] == :throttle }).to include(status: :fail, note: :throttle_not_allowed)
    end
  end

  context "with a bike that has no class" do
    let(:attributes) { super().merge(e_bike_class: nil, watts: 1_700, top_assist_mph: 50, throttle: true) }

    it "fails" do
      expect(statuses).to eq(classes: :fail, power: :fail, speed: :fail, throttle: :info)
      expect(rules.find { it[:id] == :speed }).to include(note: :speed_over_cap, args: {mph: 50, cap: 28})
      expect(described_class.verdict(rules)).to eq :red
    end
  end

  context "with a bike whose class Bike Book can't tell" do
    let(:attributes) { super().merge(e_bike_class: nil, class_unknown: true, watts: 500, top_assist_mph: nil) }

    it "is one to check rather than a failure" do
      expect(statuses).to eq(classes: :check, power: :pass, speed: :info, throttle: :pass)
      expect(rules.first).to include(note: :class_unknown)
      expect(described_class.verdict(rules)).to eq :yellow
    end
  end

  context "with a throttle under a law that doesn't say whether one is allowed" do
    let(:law) { EbikeRuleServices::StateLaws.find("IN").merge(throttle: nil) }
    let(:attributes) { super().merge(e_bike_class: 2, throttle: true) }

    it "is one to check rather than a failure" do
      expect(rules.last).to include(status: :check, note: :throttle_not_stated)
      expect(described_class.verdict(rules)).to eq :yellow
    end
  end

  context "with a law that caps neither power nor speed" do
    let(:law) { EbikeRuleServices::StateLaws.find("IN").merge(watt_cap: nil, mph: nil) }

    it "passes" do
      expect(rules.first(3).map { it[:note] }).to eq %i[class_recognized no_watt_cap no_speed_cap]
      expect(described_class.verdict(rules)).to eq :green
    end
  end

  context "with unknown watts and speed" do
    let(:attributes) { super().merge(watts: nil, top_assist_mph: nil) }

    it "informs rather than fails" do
      expect(statuses).to include(power: :info, speed: :info)
      expect(described_class.verdict(rules)).to eq :green
    end
  end

  it "is gray without a law" do
    expect(described_class.verdict([])).to eq :gray
  end
end
