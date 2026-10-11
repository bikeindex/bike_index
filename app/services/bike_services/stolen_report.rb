# frozen_string_literal: true

module BikeServices
  # The stolen report wizard: its steps, and its submission - the bike's stolen record, created or
  # updated, and the Bike Book stock photo picked in place of the owner's own
  module StolenReport
    extend Functionable

    STEPS = %w[where lock photos police contact extra review].freeze
    # The step each one is entered on, so a submission missing one reopens it
    REQUIRED = {date: "where", city: "where", postal_code: "where", theft_description: "lock"}.freeze
    RECORD_ATTRIBUTES = %i[street city region_record_id region_string postal_code country_id
      locking_description lock_defeat_description theft_description police_report_number police_report_department
      phone secondary_phone phone_for_police phone_for_shops phone_for_users receive_notifications estimated_value].freeze
    PERMITTED_PARAMS = (RECORD_ATTRIBUTES + %i[date time timezone value_unknown proof_of_ownership stock_photo_id]).freeze

    def step(value) = STEPS.include?(value) ? value : STEPS.first

    # The required answers left blank - and a date that hasn't happened yet, which is as good as one
    def missing(params)
      REQUIRED.keys.select { params[it].blank? || (it == :date && future_date?(params[:date])) }
    end

    # Tomorrow is allowed, since the owner's day can be ahead of the server's
    def future_date?(date)
      date.present? && (Date.parse(date.to_s) > Time.current.to_date + 1)
    rescue Date::Error
      false
    end

    # Saves nothing while a required answer is missing, returning false
    def save(bike:, user:, params:)
      return false if missing(params).any?

      bike_params = {"stolen_records_attributes" => {"0" => stolen_attrs(params)}}
      stock_photo_url = stock_photo_url(params[:stock_photo_id])
      bike_params["stock_photo_url"] = stock_photo_url if stock_photo_url.present?
      BikeServices::Updator.new(user:, bike:, current_ownership: bike.current_ownership,
        permitted_params: {"bike" => bike_params}).update_available_attributes
      return false if bike.reload.current_stolen_record.blank?

      BikeServices::Register.stolen_report_finished(bike)
      true
    end

    #
    # private below here
    #

    def stolen_attrs(params)
      params.to_h.except("date", "time", "value_unknown", "stock_photo_id")
        .merge("date_stolen" => params.values_at(:date, :time).compact_blank.join(" "),
          "estimated_value" => (params[:estimated_value] unless Binxtils::InputNormalizer.boolean(params[:value_unknown])),
          # "unsure" is an answer, unlike a blank - but the record stores it the same way
          "proof_of_ownership" => (params[:proof_of_ownership] if params[:proof_of_ownership] != "unsure"))
    end

    # Looked up rather than taken from the form - the alert image job downloads it
    def stock_photo_url(id)
      return if id.blank? || !id.match?(Integrations::Bikebook::Catalog::MODEL_ID)

      Integrations::Bikebook::Catalog.vehicle(id)&.dig(:image_url)
    rescue Integrations::Bikebook::Catalog::Unreachable
      nil
    end

    conceal :stolen_attrs, :stock_photo_url
  end
end
