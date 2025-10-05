class Admin::MailchimpValuesController < Admin::BaseController
  include SortableTable

  def index
    @mailchimp_values = matching_mailchimp_values.order(sort_column + " " + sort_direction)
  end

  def create
    UpdateMailchimpValuesJob.perform_async
    flash[:success] = "Updating the Mailchimp Values"
    redirect_back(fallback_location: admin_mailchimp_values_path)
  end

  protected

  def sortable_columns
    %w[name slug list kind created_at updated_at]
  end

  def matching_mailchimp_values
    if MailchimpValue.lists.include?(params[:search_list])
      @list = params[:search_list]
      MailchimpValue.where(list: @list)
    else
      @list = "all"
      MailchimpValue
    end
  end
end
