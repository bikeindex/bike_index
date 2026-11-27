# frozen_string_literal: true

module Integrations
  module Shopify
    # Shops record serials in free text - an order note, a note attribute, or a line item
    # property - so every string a sale carries gets scanned
    module SerialParser
      extend Functionable

      LABEL_WORDS = /(?:serial|s\s*[\/.]\s*n\.?)\s*(?:num(?:ber)?|no\.?)?/i
      # Punctuation ends the label, or whitespace does when the value carries a digit -
      # unanchored, "serial number not recorded" would capture "not". A bare "sn" needs the
      # punctuation branch, since it otherwise matches inside "snowboard"
      SERIAL_MATCHER = /\b(?:(?:#{LABEL_WORDS}|sn\s*(?:num(?:ber)?|no\.?)?)\s*[:#=-]\s*|#{LABEL_WORDS}\s+(?=[a-z0-9-]*\d))([a-z0-9][a-z0-9-]{2,})/i

      def serials_in(text)
        return [] if text.blank?

        text.to_s.scan(SERIAL_MATCHER).flatten.filter_map { registerable(it) }.uniq
      end

      # note_attributes and line item properties are name/value pairs, where the name carries
      # the label the matcher needs and the value is the bare serial
      def serials_in_attributes(attributes)
        return [] unless attributes.is_a?(Array)

        attributes.flat_map { serials_in("#{it["name"]}: #{it["value"]}") }.uniq
      end

      #
      # private below here
      #

      # "Serial: none" is a shop saying there's nothing to register
      def registerable(str)
        corrected = SerialNormalizer.unknown_and_absent_corrected(str)
        return nil if %w[unknown made_without_serial].include?(corrected)

        corrected
      end

      conceal :registerable
    end
  end
end
