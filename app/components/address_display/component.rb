# frozen_string_literal: true

module AddressDisplay
  class Component < ApplicationComponent
    def initialize(address_record:, address_hash:, visible_attribute:)
      @address_record = address_record
      @address_hash = address_hash
      @visible_attribute = visible_attribute
    end
  end
end
