# frozen_string_literal: true

module Admin::AddressRecordCell
  class Component < ApplicationComponent
    def initialize(address_record:)
      @address_record = address_record
    end

    def render?
      @address_record.present?
    end
  end
end
