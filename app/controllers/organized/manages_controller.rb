module Organized
  class ManagesController < Organized::AdminController
    before_action :assign_organization, only: [:show, :update, :locations]
    before_action :ensure_appointments_enabled!, only: [:schedule]

    def show
      @organization.ensure_auto_user
    end

    def locations; end

    def schedule

    end

    def update
      if @organization.update_attributes(permitted_parameters)
        flash[:success] = translation(:updated_successfully, org_name: current_organization.name)
        redirect_path = params[:locations_page] ? locations_organization_manage_path(organization_id: current_organization.to_param) : current_root_path
        redirect_to redirect_path
      else
        @page_errors = @organization.errors
        flash[:error] = translation(:could_not_update, org_name: current_organization.name)
        render :show
      end
    end

    def destroy
      organization_name = current_organization.name
      if current_organization.is_paid
        flash[:info] = translation(:contact_support_to_delete, org_name: organization_name)
        redirect_to current_root_path and return
      end
      notify_admins("organization_destroyed")
      current_organization.destroy
      flash[:info] = translation(:deleted_org, org_name: organization_name)
      redirect_to user_root_url
    end

    def landing
      render "/landing_pages/show"
    end

    private

    def assign_organization
      @organization = current_organization
    end

    def current_root_path
      organization_manage_path(organization_id: current_organization.to_param)
    end

    def permitted_parameters
      params.require(:organization).permit(:name, :website, :embedable_user_email, :short_name,
                                           show_on_map_if_permitted, permitted_kind, paid_attributes,
                                           locations_attributes: permitted_locations_params)
    end

    def permitted_kind
      return "ambassador" if @organization.ambassador?
      new_kind = params.dig(:organization, :kind)
      Organization.user_creatable_kinds.include?(new_kind) ? new_kind : @organization.kind
    end

    def show_on_map_if_permitted
      current_organization.lock_show_on_map ? [] : [:show_on_map]
    end

    def paid_attributes
      current_organization.is_paid ? [:avatar] : []
    end

    def permitted_locations_params
      %w(name zipcode city state_id country_id street phone email id _destroy)
    end

    def notify_admins(type)
      AdminNotifier.new.for_organization(organization: current_organization, user: current_user, type: type)
    end
  end
end
