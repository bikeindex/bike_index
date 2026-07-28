# frozen_string_literal: true

module Admin
  # Backs the selection chips for the multiselect organizations combobox on the bike edit
  # form (Admin::Bikes::Edit::Component)
  class ComboboxController < Admin::BaseController
    # Only ever renders turbo_stream
    before_action { request.format = :turbo_stream }

    def organization_chips
      organizations = Organization.unscoped.where(id: combobox_values).index_by { it.id.to_s }

      render turbo_stream: helpers.hw_combobox_selection_chips_for(combobox_values.filter_map { organizations[it] },
        display: :name)
    end

    private

    # Selection order, so adding an organization appends its chip
    def combobox_values
      @combobox_values ||= params[:combobox_values].to_s.split(",")
    end
  end
end
