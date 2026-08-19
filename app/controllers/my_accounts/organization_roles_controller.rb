# frozen_string_literal: true

module MyAccounts
  class OrganizationRolesController < ApplicationController
    include Sessionable

    before_action :authenticate_user_for_my_accounts_controller

    # Drag-and-drop reordering on the organization roles page
    def update
      organization_role = current_user.organization_roles.find(params[:id])
      organization_role.reorder_to!(params[:position].to_i)
      head :ok
    end
  end
end
