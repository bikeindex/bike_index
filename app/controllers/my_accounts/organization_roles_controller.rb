# frozen_string_literal: true

module MyAccounts
  class OrganizationRolesController < ApplicationController
    include Sessionable

    before_action :authenticate_user_for_my_accounts_controller
    before_action :find_organization_role

    # Drag-and-drop reordering on the organization roles page
    def update
      @organization_role.reorder_to!(params[:position].to_i)
      head :ok
    end

    def destroy
      organization_name = @organization_role.organization.short_name

      if @organization_role.leavable?
        @organization_role.destroy
        flash[:success] = translation(:left_organization, org_name: organization_name)
      else
        flash[:error] = translation(:unable_to_leave, org_name: organization_name)
      end
      redirect_to edit_my_account_path(edit_template: "organization_roles")
    end

    private

    def find_organization_role
      @organization_role = current_user.organization_roles.find(params[:id])
    end
  end
end
