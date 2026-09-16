# frozen_string_literal: true

module ComponentStructs
  # The column set, its labels and the active filters of an organization's registration
  # search — read by the wrappers, the bikes table and the column-toggle Stimulus controller
  # around the panel Pages::Org::Search::Settings renders, so it's built once and passed whole.
  #
  # The labels stay in that component's translation scope; moving them would strand the four
  # translation.*.yml.
  class OrgSearchSettings
    I18N_SCOPE = %i[components pages org search settings].freeze

    COLUMN_RENAME_KEYS = %i[
      created_at_cell
      updated_at_cell
      stolen_cell
      serial_number_cell
      manufacturer_cell
      model_cell
      color_cell
      owner_email_cell
      creation_description_cell
      owner_name_cell
      reg_organization_affiliation_cell
      reg_extra_registration_number_cell
      reg_phone_cell
      reg_address_cell
      reg_student_id_cell
      notes_cell
      sticker_cell
      impound_id_cell
      impounded_cell
      avery_cell
      cycle_type_cell
      propulsion_type_cell
      status_cell
      url_cell
    ].freeze

    ORG_PREFIXED_COLUMNS = %i[reg_organization_affiliation_cell reg_student_id_cell notes_cell].freeze

    FILTER_DESCRIPTION_KEYS = {
      search_stickers: {with: :filter_with_stickers_html, none: :filter_no_sticker_html},
      search_address: {with_street: :filter_with_address_html, without_street: :filter_no_address_html},
      search_status: {not_impounded: :filter_not_impounded_html, impounded: :filter_impounded_html,
                      with_owner: :filter_not_stolen_or_impounded_html, stolen: :filter_stolen_html}
    }.freeze

    DEFAULT_COLUMNS = %w[created_at_cell stolen_cell manufacturer_cell model_cell
      color_cell owner_email_cell owner_name_cell creation_description_cell].freeze

    ALWAYS_ENABLED_COLUMNS = %w[url_cell updated_at_cell serial_number_cell cycle_type_cell
      propulsion_type_cell status_cell].freeze

    attr_reader :organization, :search_stickers, :search_address, :search_status

    def initialize(organization:, interpreted_params: {}, sortable_search_params: {}, params: {},
      search_stickers: nil, search_address: nil, search_status: "all")
      @organization = organization
      @interpreted_params = interpreted_params || {}
      @sortable_search_params = sortable_search_params || {}
      @params = params
      @search_stickers = search_stickers
      @search_address = search_address
      @search_status = search_status
    end

    def active_search_filter_descriptions
      values = {search_stickers: @search_stickers, search_address: @search_address, search_status: @search_status}

      FILTER_DESCRIPTION_KEYS.filter_map do |param, mapping|
        value = values[param]
        key = mapping[value.to_sym] if value.is_a?(String)
        translation(key) if key
      end
    end

    def initially_checked_columns
      @initially_checked_columns ||= DEFAULT_COLUMNS +
        (@organization.enabled?("bike_stickers") ? ["sticker_cell"] : []) +
        ((@params[:search_impoundedness] == "impounded") ? ["impounded_cell"] : [])
    end

    # Stimulus wiring for the column-toggle panel, shared by every caller that renders it
    def column_toggle_data_attributes
      {controller: "org--search org--search-column-toggle",
       "org--search-column-toggle-default-columns-value": initially_checked_columns.to_json}
    end

    def column_renames
      @column_renames ||= COLUMN_RENAME_KEYS.to_h { |key|
        name = translation(key)
        name = "#{@organization.short_name} #{name}" if ORG_PREFIXED_COLUMNS.include?(key)
        [key, name]
      }
    end

    def enabled_columns
      @enabled_columns ||= begin
        cols = initially_checked_columns + ALWAYS_ENABLED_COLUMNS +
          additional_registration_fields.map { |field| "#{field}_cell" } +
          (@organization.enabled?("registration_notes") ? ["notes_cell"] : []) +
          (@organization.enabled?("impound_bikes") ? %w[impound_id_cell impounded_cell] : []) +
          (@organization.enabled?("avery_export") ? ["avery_cell"] : [])
        cols.uniq.sort_by { |cell| column_renames[cell.to_sym] }
      end
    end

    def additional_registration_fields
      @additional_registration_fields ||= @organization.additional_registration_fields - ["reg_bike_sticker"]
    end

    def cycle_type
      @cycle_type ||= if BikeServices::Displayer.vehicle_search?(@params.merge(@interpreted_params))
        translation(:vehicle)
      else
        translation(:bike)
      end
    end

    def default_open?
      @search_stickers.present? || @search_address.present? ||
        @params[:search_impoundedness].present? || Binxtils::InputNormalizer.boolean(@params[:search_open])
    end

    def search_params
      @search_params ||= @sortable_search_params
        .merge(@interpreted_params.merge(organization_id: @organization.to_param))
    end

    private

    def translation(key)
      ActiveSupport::HtmlSafeTranslation.translate(key, scope: I18N_SCOPE)
    end
  end
end
