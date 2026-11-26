module Admin
  class OrganizationMessagesController < Admin::BaseController
    include Binxtils::SortableTable

    def index
      @per_page = permitted_per_page(default: 50)
      @pagy, @collection = pagy(:countish,
        matching_organization_messages.includes(:bike, :organization, :sender, :receiver)
          .reorder(sortable_order(OrganizationMessage)),
        limit: @per_page,
        page: permitted_page)
    end

    helper_method :matching_organization_messages

    private

    def sortable_columns
      %w[created_at organization_id bike_id sender_id receiver_id]
    end

    def earliest_period_date
      Time.at(1790319600) # 2026-09-25 00:00 - organization_messages table created
    end

    def matching_organization_messages
      organization_messages = OrganizationMessage
      if params[:search_bike_id].present?
        @bike = Bike.unscoped.find_by(id: params[:search_bike_id])
        organization_messages = organization_messages.where(bike_id: params[:search_bike_id])
      end
      if params[:user_id].present?
        user_id = user_subject&.id || params[:user_id]
        organization_messages = organization_messages.where(sender_id: user_id).or(organization_messages.where(receiver_id: user_id))
      end
      if params[:search_email].present?
        organization_messages = organization_messages.where(receiver_email: EmailNormalizer.normalize(params[:search_email]))
      end
      organization_messages = organization_messages.where(organization_id: current_organization.id) if current_organization.present?
      organization_messages.where(created_at: @time_range)
    end
  end
end
