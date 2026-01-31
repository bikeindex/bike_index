# frozen_string_literal: true

module UI::AddressDisplay
  class Component < ApplicationComponent
    KINDS = %i[multiline single_line]
    def initialize(address_record: nil, address_hash: nil, visible_attribute: nil, render_country: false, kind: nil)
      @kind = KINDS.include?(kind) ? kind : KINDS.first
      @address_record = address_record
      @address_hash = address_hash&.with_indifferent_access
      @visible_attribute = AddressRecord.permitted_visible_attribute(visible_attribute)
      @render_country = render_country
    end

    def render?
      @address_record.present? || @address_hash.present?
    end

    def call
      content_tag(:span, address_content_tags, class: "tw:leading-[1.5]")
    end

    private

    def address_content_tags
      content_tags = [final_line]

      if @visible_attribute == :street
        content_tags = street_tags + content_tags
      end

      content_tags.reduce(:+)
    end

    def street_tags
      street_lines = if @address_record.present?
        [@address_record.street, @address_record.street_2]
      else
        @address_hash[:street]&.split(",")&.map(&:strip)
      end.compact

      street_lines.map { content_tag(:span, it + line_separator, class: line_classes) }
    end

    def final_line
      if @address_record.present?
        final_line = [@address_record.region]
        final_line += [@address_record.postal_code] unless @visible_attribute == :city

        final_line = [@address_record.city, final_line.join(" ")]
        final_line += [@address_record.country_name] if @render_country
      else
        final_line = [@address_hash[:state]]
        final_line += [@address_hash[:zipcode]] unless @visible_attribute == :city

        final_line = [@address_hash[:city], final_line.join(" ")]
        final_line += [@address_hash[:country]] if @render_country
      end

      content_tag(:span, final_line.compact.join(", "), class: line_classes)
    end

    def single_line?
      @kind == :single_line
    end

    def line_separator
      single_line? ? ", " : "\n"
    end

    def line_classes
      single_line? ? "tw:inline-block" : "tw:block"
    end
  end
end
