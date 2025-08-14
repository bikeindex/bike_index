module Organized
  class UsersController < Organized::AdminController
    include SortableTable
    before_action :find_organization_role, only: [:edit, :update, :destroy]
    before_action :reject_self_updates, only: [:update, :destroy]

    def index
      params[:page] || 1
      per_page = (params[:per_page] || 25).to_i
      @show_user_search = params[:query].present? || current_organization.organization_roles.count > per_page
      @show_matching_count = @show_user_search && params[:query].present?
      @pagy, @organization_roles = pagy(
        matching_organization_roles.reorder("organization_roles.#{sort_column} #{sort_direction}"),
        limit: per_page,
        page: permitted_page
      )
    end

    def edit
    end

    def update
      @organization_role.update(permitted_update_params)
      flash[:success] = translation(:updated_organization_role, user_email: @organization_role.user&.email)
      redirect_to current_root_path
    end

    def destroy
      @organization_role.destroy
      flash[:success] = translation(:deleted_user)
      redirect_to current_root_path
    end

    def new
      @organization_role ||= OrganizationRole.new(organization_id: current_organization.id)
      @page_errors = @organization_role.errors
    end

    def create
      if current_organization.restrict_invitations? && current_organization.remaining_invitation_count < 1
        flash[:error] = translation(:no_remaining_user_invitations, org_name: current_organization.name)
        redirect_to(current_root_path) && return
      end
      @organization_role = OrganizationRole.new(permitted_create_params)
      if params[:multiple_emails_invited].present?
        if current_organization.restrict_invitations? && (multiple_emails_invited.count > current_organization.remaining_invitation_count)
          flash[:error] = translation(:insufficient_invitations,
            invite_count: multiple_emails_invited.count,
            org_name: current_organization.name,
            remaining_invite_count: current_organization.remaining_invitation_count)
          render :new
        else
          flash[:success] = translation(:users_invited,
            invite_count: multiple_emails_invited.count,
            org_name: current_organization.name)
          multiple_emails_invited
            .each { |email| OrganizationRole.create(permitted_create_params.merge(invited_email: email)) }

          redirect_to(current_root_path) && return
        end
      elsif @organization_role.save
        flash[:success] = translation(:user_was_invited,
          invited_email: @organization_role.invited_email,
          org_name: current_organization.name)
        redirect_to current_root_path
      else
        render :new
      end
    end

    private

    def sortable_columns
      %w[created_at invited_email sender_id claimed_at role]
    end

    def matching_organization_roles
      m_organization_roles = current_organization.organization_roles.includes(:user, :sender)
      return m_organization_roles unless params[:query].present?
      m_organization_roles.admin_text_search(params[:query])
    end

    def current_root_path
      organization_users_path(organization_id: current_organization.to_param)
    end

    def find_organization_role
      @organization_role = current_organization.organization_roles.find(params[:id])
    end

    def reject_self_updates
      if @organization_role && @organization_role.user == current_user
        flash[:error] = translation(:cannot_remove_yourself)
        redirect_to(organization_users_path(organization_id: current_organization)) && return
      end
    end

    def multiple_emails_invited
      params[:multiple_emails_invited].split(/\s+/).flatten.reject(&:blank?).uniq
    end

    def permitted_update_params
      params.require(:organization_role).permit(:role).merge(organization_id: current_organization.id)
    end

    def permitted_create_params
      params.require(:organization_role).permit(:role, :invited_email)
        .merge(organization: current_organization, sender: current_user)
    end

    def update_organization_role_params
      {role: params.dig(:organization_role, :role)}
    end
  end
end
