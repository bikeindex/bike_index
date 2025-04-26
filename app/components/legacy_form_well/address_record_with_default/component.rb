# frozen_string_literal: true

module LegacyFormWell::AddressRecordWithDefault
  class Component < ApplicationComponent
    def initialize(form_builder:, user:, no_street: false)
      @builder = form_builder
      @user = user
      @no_street = no_street
    end

    private

    def render_use_default_record?
      return false if @user.address_record.blank?

      true
    end
  end
end
