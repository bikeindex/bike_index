# frozen_string_literal: true

module ComponentStructs
  # The column set, its labels and the active filters of an organization's registration
  # search. Everything around the panel Pages::Org::Search::ColumnSettings renders reads the
  # same values, so it's built once and passed whole.
  #
  # Its copy sits in that panel's sidecar — the only home the component's cache digest reaches.
  class OrgSearchSettings
    TRANSLATION_SCOPE = %i[components pages org search column_settings].freeze

    COLUMN_RENAME_KEYS = %i[
      view_cell
      photo_cell
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
      acknowledgment_cell
      cycle_type_cell
      propulsion_type_cell
      status_cell
      url_cell
    ].freeze

    # Their labels name the organization, italicized with its preposition
    ORG_NAMED_COLUMNS = %i[notes_cell reg_organization_affiliation_cell reg_student_id_cell].freeze

    # Each filter's values and their labels, once — `filter_groups` lays them out,
    # `filter_values` is the set the controller permits, and `active_search_filter_descriptions`
    # names the ones in force. feature gates the whole row, value_feature an individual
    # option; blank is the row's "not filtering".
    FILTER_GROUPS = {
      search_stickers: {label: :stickers, feature: "bike_stickers",
                        values: {with: :filter_with_stickers_html, none: :filter_no_sticker_html}},
      search_address: {label: :address, feature: "reg_address",
                       values: {with_street: :filter_with_address_html,
                                without_street: :filter_no_address_html}},
      search_status: {label: :status, blank: "all",
                      value_feature: {not_impounded: "impound_bikes", impounded: "impound_bikes"},
                      values: {not_impounded: :filter_not_impounded_html,
                               impounded: :filter_impounded_html,
                               with_owner: :filter_not_stolen_or_impounded_html,
                               stolen: :filter_stolen_html}},
      search_unregisteredness: {label: :unregistered,
                                values: {only_unregistered: :filter_only_unregistered_html,
                                         only_registered: :filter_not_unregistered_html}}
    }.freeze

    DEFAULT_COLUMNS = %w[photo_cell created_at_cell stolen_cell manufacturer_cell model_cell
      color_cell owner_email_cell owner_name_cell creation_description_cell].freeze

    ALWAYS_ENABLED_COLUMNS = %w[url_cell updated_at_cell serial_number_cell cycle_type_cell
      propulsion_type_cell status_cell].freeze

    # Listed in the panel, but checked and disabled - the table always shows them
    ALWAYS_VISIBLE_COLUMNS = %w[view_cell].freeze

    attr_reader :organization

    # The values an organization's panel offers for a filter, blank first — empty if the
    # whole row is gated off. The search permits these and nothing else
    def self.filter_values(name, organization)
      group = FILTER_GROUPS.fetch(name)
      enabled = ->(feature) { feature.nil? || organization.enabled?(feature) }
      return [] unless enabled.call(group[:feature])

      [group[:blank] || ""] + group[:values].keys.filter_map do |value|
        value.to_s if enabled.call(group[:value_feature]&.dig(value))
      end
    end

    def initialize(organization:, interpreted_params: {}, sortable_search_params: {}, params: {},
      search_stickers: nil, search_address: nil, search_status: "all", search_unregisteredness: nil,
      search_all: false)
      @organization = organization
      @interpreted_params = interpreted_params
      @sortable_search_params = sortable_search_params
      @params = params
      @filter_values = {search_stickers:, search_address:, search_status:, search_unregisteredness:}
      @search_all = search_all
    end

    def active_search_filter_descriptions
      @active_search_filter_descriptions ||= FILTER_GROUPS.filter_map do |name, group|
        value = @filter_values[name]
        key = group[:values][value.to_sym] if value.is_a?(String)
        translation(key) if key
      end
    end

    def filter_groups
      FILTER_GROUPS.filter_map do |name, group|
        next unless enabled_filter?(group[:feature])

        blank = group[:blank] || ""
        {name:, label: translation(group[:label]),
         selected: @filter_values[name].presence || blank,
         entries: [{value: blank, label: translation(:all)}] + group_entries(group)}
      end
    end

    def notes_search_label = translation(:show_notes_search)

    def render_export? = @organization.enabled?("csv_exports")

    def search_all? = @search_all

    # An export past the organization would carry other organizations' registrations
    def export_disabled? = search_all?

    def initially_checked_columns
      @initially_checked_columns ||= [
        *DEFAULT_COLUMNS,
        ("sticker_cell" if @organization.enabled?("bike_stickers")),
        ("impounded_cell" if @params[:search_impoundedness] == "impounded")
      ].compact
    end

    def column_renames
      @column_renames ||= COLUMN_RENAME_KEYS.to_h { |key|
        next [key, translation(key)] unless ORG_NAMED_COLUMNS.include?(key)

        [key, translation(:"#{key}_html", org_name: @organization.short_name)]
      }
    end

    def enabled_columns
      @enabled_columns ||= [
        *initially_checked_columns,
        *ALWAYS_ENABLED_COLUMNS,
        *additional_registration_fields.map { |field| "#{field}_cell" },
        ("notes_cell" if @organization.enabled?("registration_notes")),
        *(%w[impound_id_cell impounded_cell] if @organization.enabled?("impound_bikes")),
        ("avery_cell" if @organization.enabled?("avery_export")),
        ("acknowledgment_cell" if @organization.enabled?("registration_sequences"))
      ].compact.uniq.sort_by { |cell| column_renames[cell.to_sym] }
    end

    def panel_columns
      @panel_columns ||= (enabled_columns + ALWAYS_VISIBLE_COLUMNS).sort_by { |cell| column_renames[cell.to_sym] }
    end

    def additional_registration_fields
      @additional_registration_fields ||= @organization.additional_registration_fields - ["reg_bike_sticker"]
    end

    def search_params
      @search_params ||= @sortable_search_params
        .merge(@interpreted_params.merge(organization_id: @organization.to_param))
    end

    private

    def enabled_filter?(feature)
      feature.nil? || @organization.enabled?(feature)
    end

    def group_entries(group)
      group[:values].filter_map do |value, key|
        next unless enabled_filter?(group[:value_feature]&.dig(value))

        {value: value.to_s, label: translation(key)}
      end
    end

    def translation(key, **)
      ActiveSupport::HtmlSafeTranslation.translate(key, scope: TRANSLATION_SCOPE, **)
    end
  end
end
