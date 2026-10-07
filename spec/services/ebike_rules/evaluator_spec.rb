# frozen_string_literal: true

require "rails_helper"

RSpec.describe EbikeRules::Evaluator do
  let(:attributes) do
    {bikebook_id: "m/x/2025/y", manufacturer_name: "X", model: "Y", first_year: 2025, e_bike_class: 1, watts: 250,
     top_assist_mph: 20, throttle: false, throttle_mph: nil, ul2849: :unknown, ul2271: :unknown, photo_url: nil}
  end
  let(:bike) { EbikeRules::Bike.new(**attributes) }
  let(:law) { EbikeRules::StateLaws.find("IN") }
  let(:rules) { described_class.rules(law:, bike:) }
  let(:statuses) { rules.to_h { [it[:id], it[:status]] } }

  it "passes a Class 1 bike in Indiana" do
    expect(statuses).to eq(classes: :pass, power: :pass, speed: :pass, throttle: :pass, age: :pass, helmet: :pass,
      paths: :pass, label: :info)
    expect(described_class.verdict(rules)).to eq :green
  end

  context "with a Class 3 bike with a throttle in California" do
    let(:law) { EbikeRules::StateLaws.find("CA") }
    let(:attributes) { super().merge(e_bike_class: 3, top_assist_mph: 28, throttle: true) }

    it "is legal, with rules to check" do
      expect(statuses).to eq(classes: :pass, power: :pass, speed: :pass, throttle: :check, age: :check, helmet: :check,
        paths: :check, label: :info)
      expect(rules.find { it[:id] == :age }).to include(note: :minimum_age, args: {age: 16})
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

  context "with a bike assisting past its class's speed" do
    let(:law) { EbikeRules::StateLaws.find("NY") }
    let(:attributes) { super().merge(e_bike_class: 3, top_assist_mph: 28) }

    it "fails on speed" do
      expect(rules.find { it[:id] == :speed }).to include(status: :fail, note: :speed_over_class_cap, args: {mph: 28, cap: 25, e_bike_class: 3})
    end
  end

  context "with a bike that has no class" do
    let(:attributes) { super().merge(e_bike_class: nil, watts: 1_700, top_assist_mph: 50, throttle: true) }

    it "fails, without the rules for riding an e-bike" do
      expect(statuses).to eq(classes: :fail, power: :fail, speed: :fail, throttle: :info, label: :info)
      expect(rules.find { it[:id] == :speed }).to include(note: :speed_over_cap, args: {mph: 50, cap: 28})
      expect(described_class.verdict(rules)).to eq :red
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
