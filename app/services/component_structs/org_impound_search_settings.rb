# frozen_string_literal: true

module ComponentStructs
  # The impound records search's filters, in the shape Pages::Org::Search::SettingsAndFilters
  # reads off ComponentStructs::OrgSearchSettings
  class OrgImpoundSearchSettings
    TRANSLATION_SCOPE = %i[components pages org impound_records index].freeze

    UNREGISTEREDNESS_LABELS = {
      "all" => :all_bikes,
      "only_unregistered" => :only_unregistered,
      "only_registered" => :only_user_registered
    }.freeze

    def initialize(statuses:, search_status:, search_unregisteredness:)
      @statuses = statuses
      @search_status = search_status
      @search_unregisteredness = search_unregisteredness
    end

    def notes_search? = false

    def location_search? = false

    def filter_groups
      [
        {name: :search_status, label: translation(:status), selected: @search_status,
         entries: @statuses.map { {value: it, label: status_label(it)} }},
        {name: :search_unregisteredness, label: translation(:registration), selected: @search_unregisteredness,
         entries: UNREGISTEREDNESS_LABELS.map { |value, key| {value:, label: translation(key)} }}
      ]
    end

    # "all" is the one value that isn't filtering, as org--search's summary reads it
    def active_search_filter_descriptions
      [
        (status_label(@search_status) unless @search_status == "all"),
        (translation(UNREGISTEREDNESS_LABELS[@search_unregisteredness]) unless @search_unregisteredness == "all")
      ].compact
    end

    private

    def status_label(status)
      if status == "all"
        translation(:all_statuses)
      elsif ImpoundRecord.statuses.include?(status) && status != "current"
        ImpoundRecord.statuses_humanized[status.to_sym]
      else
        translation(:status_records, status: status.titleize)
      end
    end

    def translation(key, **)
      ActiveSupport::HtmlSafeTranslation.translate(key, scope: TRANSLATION_SCOPE, **)
    end
  end
end
