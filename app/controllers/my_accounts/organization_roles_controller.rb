# frozen_string_literal: true

module MyAccounts
  class OrganizationRolesController < ApplicationController
    include Sessionable

    before_action :authenticate_user_for_my_accounts_controller

    # The organization roles page's drag-and-drop reordering and on by default checkbox
    def update
      organization_role = current_user.organization_roles.find(params[:id])
      if params.key?(:on_by_default)
        organization_role.update_on_by_default!(Binxtils::InputNormalizer.boolean(params[:on_by_default]))
      else
        organization_role.reorder_to!(params[:position].to_i)
      end
      head :ok
    end
  end
end
