# frozen_string_literal: true

require "ostruct"

module UI
  module Table
    class ComponentPreview < ApplicationComponentPreview
      # @!group Variants

      def default
        colors = enthusiasm_colors
        render(UI::Table::Component.new(records: sample_records, sort: "first_seen", sort_direction: "desc")) do |table|
          table.column(label: "Cryptid", lower_right: ->(r) { r.region }) { |r| r.name }
          table.column(label: "Credibility") { |r| render(UI::Badge::Component.new(text: r.credibility, color: (r.credibility == "Confirmed") ? :success : :gray, size: :sm)) }
          table.column(label: "Enthusiasm") { |r| render(UI::Badge::Component.new(text: r.enthusiasm, color: colors[r.enthusiasm], size: :sm)) }
          table.column(label: "Sightings") { |r| number_with_delimiter(r.sightings) }
          table.column(label: safe_join(["First Seen ", tag.span(class: "localizeTimezone")]), sort_indicator: "first_seen") { |r| render(UI::Time::Component.new(time: r.first_seen)) }
        end
      end

      def sortable_with_cache
        colors = enthusiasm_colors
        render(UI::Table::Component.new(records: sample_records, cache_key: "preview-cryptids", sort: "name", sort_direction: "desc", render_sortable: true)) do |table|
          table.column(sortable: "name") { |r| r.name }
          table.column(label: "Region", header_classes: "tw:font-normal") { |r| r.region }
          table.column(label: "Credibility", header_classes: "tw:font-normal") { |r| render(UI::Badge::Component.new(text: r.credibility, color: (r.credibility == "Confirmed") ? :success : :gray, size: :sm)) }
          table.column(label: "Enthusiasm", header_classes: "tw:font-normal") { |r| render(UI::Badge::Component.new(text: r.enthusiasm, color: colors[r.enthusiasm], size: :sm)) }
          table.column(sortable: "sightings") { |r| number_with_delimiter(r.sightings) }
          table.column(label: "Rendered at", header_classes: "tw:font-normal") { |_r| tag.small(l(::Time.current, format: :convert_time), class: "localizeTime preciseTimeSeconds") }
        end
      end

      def unbordered
        colors = enthusiasm_colors
        render(UI::Table::Component.new(records: sample_records, unbordered: true, sort: "first_seen", sort_direction: "desc")) do |table|
          table.column(label: "Cryptid") { |r| r.name }
          table.column(label: "Region") { |r| r.region }
          table.column(label: "Credibility") { |r| render(UI::Badge::Component.new(text: r.credibility, color: (r.credibility == "Confirmed") ? :success : :gray, size: :sm)) }
          table.column(label: "Enthusiasm") { |r| render(UI::Badge::Component.new(text: r.enthusiasm, color: colors[r.enthusiasm], size: :sm)) }
          table.column(label: "Sightings") { |r| number_with_delimiter(r.sightings) }
          table.column(label: "First Seen", sort_indicator: "first_seen") { |r| render(UI::Time::Component.new(time: r.first_seen)) }
        end
      end

      # @!endgroup

      private

      def sample_records
        [
          OpenStruct.new(name: "Mothman", region: "West Virginia", credibility: "Medium", enthusiasm: "Extreme", sightings: 142, first_seen: ::Time.zone.parse("1966-11-15")),
          OpenStruct.new(name: "Bigfoot", region: "Pacific Northwest", credibility: "Low", enthusiasm: "Extreme", sightings: 10000, first_seen: ::Time.zone.parse("1958-08-27")),
          OpenStruct.new(name: "Loch Ness Monster", region: "Scottish Highlands", credibility: "Low", enthusiasm: "High", sightings: 1036, first_seen: ::Time.zone.parse("1933-05-02")),
          OpenStruct.new(name: "Chupacabra", region: "Puerto Rico", credibility: "Low", enthusiasm: "Medium", sightings: 87, first_seen: ::Time.zone.parse("1995-03-01")),
          OpenStruct.new(name: "Jersey Devil", region: "Pine Barrens, NJ", credibility: "Low", enthusiasm: "Low", sightings: 53, first_seen: ::Time.zone.parse("1909-01-16")),
          OpenStruct.new(name: "Okapi", region: "Congo", credibility: "Confirmed", enthusiasm: "None", sightings: 1, first_seen: ::Time.zone.parse("1901-06-01"))
        ]
      end

      def enthusiasm_colors
        {"Extreme" => :error, "High" => :warning, "Medium" => :orange, "Low" => :gray, "None" => :gray}
      end
    end
  end
end
