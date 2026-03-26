# frozen_string_literal: true

require "ostruct"

module UI
  module Table
    class ComponentPreview < ApplicationComponentPreview
      def default
        records = [
          OpenStruct.new(name: "Mothman", region: "West Virginia", credibility: "Medium", enthusiasm: "Extreme", sightings: 142, first_seen: ::Time.zone.parse("1966-11-15")),
          OpenStruct.new(name: "Bigfoot", region: "Pacific Northwest", credibility: "Low", enthusiasm: "Extreme", sightings: 10000, first_seen: ::Time.zone.parse("1958-08-27")),
          OpenStruct.new(name: "Loch Ness Monster", region: "Scottish Highlands", credibility: "Low", enthusiasm: "High", sightings: 1036, first_seen: ::Time.zone.parse("1933-05-02")),
          OpenStruct.new(name: "Chupacabra", region: "Puerto Rico", credibility: "Low", enthusiasm: "Medium", sightings: 87, first_seen: ::Time.zone.parse("1995-03-01")),
          OpenStruct.new(name: "Jersey Devil", region: "Pine Barrens, NJ", credibility: "Low", enthusiasm: "Low", sightings: 53, first_seen: ::Time.zone.parse("1909-01-16")),
          OpenStruct.new(name: "Okapi", region: "Congo", credibility: "Confirmed", enthusiasm: "None", sightings: 1, first_seen: ::Time.zone.parse("1901-06-01"))
        ]

        enthusiasm_colors = {"Extreme" => :error, "High" => :warning, "Medium" => :orange, "Low" => :gray, "None" => :gray}

        render(UI::Table::Component.new(records:)) do |table|
          table.column(label: "Cryptid") { |r| r.name }
          table.column(label: "Region") { |r| r.region }
          table.column(label: "Credibility") { |r| render(UI::Badge::Component.new(text: r.credibility, color: (r.credibility == "Confirmed") ? :success : :gray, size: :sm)) }
          table.column(label: "Enthusiasm") { |r| render(UI::Badge::Component.new(text: r.enthusiasm, color: enthusiasm_colors[r.enthusiasm], size: :sm)) }
          table.column(label: "Sightings") { |r| number_with_delimiter(r.sightings) }
          table.column(label: "First Seen") { |r| render(UI::Time::Component.new(time: r.first_seen, format: :date)) }
        end
      end

      def with_sortable_columns
        records = [
          OpenStruct.new(name: "Carol", email: "carol@example.com", role: "member", created_at: 3.hours.ago),
          OpenStruct.new(name: "Bob", email: "bob@example.com", role: "member", created_at: 1.week.ago),
          OpenStruct.new(name: "Alice", email: "alice@example.com", role: "admin", created_at: 2.days.ago)
        ]

        render(UI::Table::Component.new(records:, sort: "name", sort_direction: "desc")) do |table|
          table.column(sortable: "name") { |r| r.name }
          table.column(sortable: "email") { |r| r.email }
          table.column(label: "Role") { |r| render(UI::Badge::Component.new(text: r.role, color: (r.role == "admin") ? :purple : :gray, size: :sm)) }
          table.column(sortable: "created_at") { |r| render(UI::Time::Component.new(time: r.created_at)) }
        end
      end
    end
  end
end
