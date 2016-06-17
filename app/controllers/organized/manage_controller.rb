module Organized
  class ManageController < Organized::AdminController
    before_filter :assign_organization, only: [:index, :update, :locations]
    def index
      @organization.ensure_auto_user
    end

    def locations
    end

    def update
      if params[:locations_page]
        @organization.update_attributes(update_locations_params)
        flash[:success] = "#{current_organization.name} locations updated successfully"
        redirect_to locations_organization_manage_index_path(organization_id: current_organization.to_param)
      elsif @organization.update_attributes(update_organization_params)
        flash[:success] = "#{current_organization.name} updated successfully"
        redirect_to current_index_path
      else
        @page_errors = @organization.errors
        flash[:error] = "We're sorry, we had trouble updating #{current_organization.name}"
        render :index
      end
    end

    def dev
    end

    def destroy
      organization_name = current_organization.name
      if current_organization.is_paid
        flash[:info] = "Please contact support@bikeindex.org to delete #{organization_name}"
        redirect_to current_index_path and return
      end
      notify_admins('organization_destroyed')
      current_organization.destroy
      flash[:info] = "Deleted #{organization_name}"
      redirect_to user_root_url
    end

    private

    def assign_organization
      @organization = current_organization
    end

    def current_index_path
      organization_manage_index_path(organization_id: current_organization.to_param)
    end

    def update_organization_params
      o_params = params[:organization]
      {
        name: o_params[:name],
        website: o_params[:website],
        org_type: o_params[:org_type],
        embedable_user_email: o_params[:embedable_user_email],
      }.merge(paid_attributes(o_params))
    end

    def update_locations_params
      o_params = params[:organization]
      show_on_map(o_params)
        .merge(locations_attributes(o_params[:locations_attributes]))
    end

    def locations_attributes(locations_params)
      locations_params.present? ? locations_params : {}
    end

    def show_on_map(o_params)
      current_organization.lock_show_on_map ? {} : { show_on_map: o_params[:show_on_map] }
    end

    def paid_attributes(o_params)
      return {} unless current_organization.is_paid
      { avatar: o_params[:avatar] }
    end

    def notify_admins(type)
      AdminNotifier.new.for_organization(organization: current_organization, user: current_user, type: type)
    end
  end
end
