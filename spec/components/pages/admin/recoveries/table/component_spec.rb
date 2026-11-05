# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Recoveries::Table::Component, type: :component do
  describe "PERSONAL_INFO" do
    def kinds(text) = described_class::PERSONAL_INFO.select { |_, info| info[:pattern].match?(text) }.keys

    it "flags phone numbers, emails and street addresses" do
      ["555-123-4567", "(555) 123 4567", "+1 555.123.4567", "call 5551234567 please"].each { expect(kinds(it)).to eq([:phone]), it }
      expect(kinds("write me@Example.com")).to eq([:email])
      ["found at 123 Main St", "1200 N Main Street", "42 Elm Ave.", "lives at V6B 1A1"].each { expect(kinds(it)).to eq([:address]), it }
    end

    it "leaves ordinary stories alone" do
      ["Got it back after 2 days on the way home", "I paid 450 dollars in 2015", "A 1975 Viner Special", "Thanks Bike Index!"].each do
        expect(kinds(it)).to eq([]), it
      end
    end
  end
end
