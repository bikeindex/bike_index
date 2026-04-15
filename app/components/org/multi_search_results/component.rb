# frozen_string_literal: true

module Org::MultiSearchResults
  class Component < ApplicationComponent
    include SortableHelper

    def initialize(organization:, serial:, serial_chip_id:, pagy:, bikes:, interpreted_params:, per_page:, close_serials: nil)
      @organization = organization
      @serial = serial
      @serial_chip_id = serial_chip_id
      @pagy = pagy
      @bikes = bikes
      @interpreted_params = interpreted_params
      @per_page = per_page
      @close_serials = close_serials
    end

    private

    def result_index
      @serial_chip_id&.delete_prefix("chip_")
    end

    def show_view_all?
      @pagy.count > 10
    end

    def view_all_path
      helpers.organization_registrations_path(organization_id: @organization.to_param, search_serial: @serial)
    end
  end
end
