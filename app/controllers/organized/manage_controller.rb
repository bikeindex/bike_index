module Organized
  class ManageController < Organized::AdminController
    before_filter :assign_organization, only: [:index, :update, :locations]
    def index
      @organization.ensure_auto_user
    end

    def locations
    end

    def update
      if @organization.update_attributes(update_organization_params)
        flash[:success] = "#{current_organization.name} updated successfully"
        redirect_path = params[:locations_page] ? locations_organization_manage_index_path(organization_id: current_organization.to_param) : current_index_path
        redirect_to redirect_path
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
      params[:organization].slice(:name, :website, :org_type, :embedable_user_email)
                           .merge(additional_attributes(params[:organization]))
    end

    def additional_attributes(o_params)
      show_on_map(o_params).merge(paid_attributes(o_params))
                           .merge(locations_attributes(o_params[:locations_attributes]))
    end

    def locations_attributes(locations_attributes)
      return {} unless locations_attributes.present?
      locations_attributes.each { |k, hash| locations_attributes[k] = permitted_locations_attrs(hash) }
      { locations_attributes: locations_attributes }
    end

    def show_on_map(o_params)
      current_organization.lock_show_on_map ? {} : o_params.slice(:show_on_map)
    end

    def paid_attributes(o_params)
      return {} unless current_organization.is_paid
      o_params.slice(:avatar)
    end

    def permitted_locations_attrs(hash)
      hash.slice(:name, :zipcode, :city, :state_id, :country_id, :street, :phone, :email, :id)
          .merge(organization_id: current_organization.id)
    end

    def notify_admins(type)
      AdminNotifier.new.for_organization(organization: current_organization, user: current_user, type: type)
    end
  end
end
