class Admin::InboundEmailsController < Admin::BaseController
  include SortableTable

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @collection = pagy(:countish,
      matching_inbound_emails.reorder(sortable_opts),
      limit: @per_page,
      page: permitted_page)
  end

  def show
    @inbound_email = ActionMailbox::InboundEmail.find(params[:id])
  end

  helper_method :matching_inbound_emails

  protected

  def sortable_columns
    %w[created_at status]
  end

  def sortable_opts
    "action_mailbox_inbound_emails.#{sort_column} #{sort_direction}"
  end

  def matching_inbound_emails
    inbound_emails = ActionMailbox::InboundEmail.all

    if params[:search_status].present?
      inbound_emails = inbound_emails.where(status: params[:search_status])
    end

    inbound_emails.where(created_at: @time_range)
  end
end
