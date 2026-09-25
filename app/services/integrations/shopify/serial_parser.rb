# frozen_string_literal: true

module Integrations
  module Shopify
    # Shops record serials in free text - an order note, a note attribute, or a line item
    # property - so every string a sale carries gets scanned
    module SerialParser
      extend Functionable

      # Interpolating a Regexp embeds its flags, so this one carries its own /i
      LABEL = /(?:serial|s\s*[\/.]\s*n\.?|sn)\s*(?:num(?:ber)?|no\.?)?/i
      PUNCTUATED = /\b#{LABEL}\s*[:#=-]\s*([a-z0-9][a-z0-9-]{2,})/i
      # With no punctuation to end the label, "serial number not recorded" would capture
      # "not" - a digit is what tells a serial from the next word of a sentence. Bare "sn"
      # is excluded here too, since it otherwise matches inside "snowboard"
      SPACED = /\b(?:serial|s\s*[\/.]\s*n\.?)\s*(?:num(?:ber)?|no\.?)?\s+((?=[a-z0-9-]*\d)[a-z0-9][a-z0-9-]{2,})/i

      def serials_in(text)
        return [] if text.blank?

        [PUNCTUATED, SPACED].flat_map { text.to_s.scan(it).flatten }
          .filter_map { registerable(it) }.uniq
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

      # "Serial: none" is a shop saying there's nothing to register, not a serial to register
      def registerable(str)
        corrected = SerialNormalizer.unknown_and_absent_corrected(str)
        return nil if %w[unknown made_without_serial].include?(corrected)

        corrected
      end

      conceal :registerable
    end
  end
end
