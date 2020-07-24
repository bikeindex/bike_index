module Organized
  class UsersController < Organized::AdminController
    include SortableTable
    before_action :find_membership, only: [:edit, :update, :destroy]
    before_action :reject_self_updates, only: [:update, :destroy]

    def index
      page = params[:page] || 1
      per_page = params[:per_page] || 25
      @show_user_search = params[:query].present? || current_organization.memberships.count > per_page
      @show_matching_count = @show_user_search && params[:query].present?
      @memberships =
        matching_memberships.reorder("memberships.#{sort_column} #{sort_direction}")
          .page(page)
          .per(per_page)
    end

    def edit
    end

    def update
      @membership.update_attributes(permitted_update_params)
      flash[:success] = translation(:updated_membership, user_email: @membership.user&.email)
      redirect_to current_root_path
    end

    def destroy
      @membership.destroy
      flash[:success] = translation(:deleted_user)
      redirect_to current_root_path
    end

    def new
      @membership ||= Membership.new(organization_id: current_organization.id)
      @page_errors = @membership.errors
    end

    def create
      if current_organization.restrict_invitations? && current_organization.remaining_invitation_count < 1
        flash[:error] = translation(:no_remaining_user_invitations, org_name: current_organization.name)
        redirect_to(current_root_path) && return
      end
      @membership = Membership.new(permitted_create_params)
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
            .each { |email| Membership.create(permitted_create_params.merge(invited_email: email)) }

          redirect_to(current_root_path) && return
        end
      else
        if @membership.save
          flash[:success] = translation(:user_was_invited,
            invited_email: @membership.invited_email,
            org_name: current_organization.name)
          redirect_to current_root_path
        else
          render :new
        end
      end
    end

    private

    def sortable_columns
      %w[created_at invited_email sender_id claimed_at]
    end

    def matching_memberships
      m_memberships = current_organization.memberships.includes(:user, :sender)
      return m_memberships unless params[:query].present?
      m_memberships.admin_text_search(params[:query])
    end

    def current_root_path
      organization_users_path(organization_id: current_organization.to_param)
    end

    def find_membership
      @membership = current_organization.memberships.find(params[:id])
    end

    def reject_self_updates
      if @membership && @membership.user == current_user
        flash[:error] = translation(:cannot_remove_yourself)
        redirect_to(organization_users_path(organization_id: current_organization)) && return
      end
    end

    def multiple_emails_invited
      params[:multiple_emails_invited].split(/\s+/).flatten.reject(&:blank?).uniq
    end

    def permitted_update_params
      params.require(:membership).permit(:role).merge(organization_id: current_organization.id)
    end

    def permitted_create_params
      params.require(:membership).permit(:role, :invited_email)
        .merge(organization: current_organization, sender: current_user)
    end

    def update_membership_params
      {role: params.dig(:membership, :role)}
    end
  end
end
