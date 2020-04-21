module Organized
  class ImpoundRecordsController < Organized::BaseController
    include SortableTable
    before_action :set_period, only: [:index]

    def index
      @page = params[:page] || 1
      @per_page = params[:per_page] || 25
      @impound_records = available_impound_records.reorder("impound_records.#{sort_column} #{sort_direction}")
                                                  .page(@page).per(@per_page)
    end

    def show
      @impound_record = impound_records.find(params[:id])
    end

    private

    def impound_records
      current_organization.impound_records
    end

    def sortable_columns
      %w[created_at]
    end

    def available_impound_records
      impound_records
    end
  end
end
