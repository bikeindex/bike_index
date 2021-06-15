class Admin::MailchimpValuesController < Admin::BaseController
  include SortableTable

  def index
    @mailchimp_values = MailchimpValue.order(sort_column + " " + sort_direction)
  end

  def create
    MailchimpValue.lists.each do |list|
      MailchimpValue.kinds.each do |kind|
        UpdateMailchimpValuesWorker.perform_async(list, kind)
      end
    end
    flash[:success] = "Updating the Mailchimp Values"
    redirect_back(fallback_location: admin_mailchimp_values_path)
  end

  protected

  def sortable_columns
    %w[slug list kind created_at updated_at]
  end
end
