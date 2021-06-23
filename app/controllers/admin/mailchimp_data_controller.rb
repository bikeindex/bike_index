class Admin::MailchimpDataController < Admin::BaseController
  include SortableTable

  before_action :set_period, only: [:index]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 50
    @mailchimp_data = matching_mailchimp_data.includes(:user, :feedbacks)
      .page(page).per(per_page)
  end

  helper_method :matching_mailchimp_data

  protected

  def sortable_columns
    %w[created_at email updated_at mailchimp_updated_at status]
  end

  def earliest_period_date
    Time.at(1621109647) # 2021-05-15 - Pretty sure before any mailchimp stuff
  end

  def matching_mailchimp_data
    @search_users = %w[with_user no_user].include?(params[:search_users]) ? params[:search_users] : "all"
    m_mailchimp_data = if @search_users == "with_user"
      MailchimpDatum.with_user
    elsif @search_users == "no_user"
      MailchimpDatum.no_user
    else
      MailchimpDatum
    end
    if MailchimpValue.lists.include?(params[:search_list])
      @list = params[:search_list]
      m_mailchimp_data = m_mailchimp_data.list(@list)
    else
      @list = "all"
    end
    m_mailchimp_data = m_mailchimp_data.where("email ILIKE ?", "%#{params[:query]}%") if params[:query].present?
    @time_range_column = sort_column if %w[updated_at mailchimp_updated_at].include?(sort_column)
    @time_range_column ||= "created_at"

    m_mailchimp_data.order(sort_column + " " + sort_direction)
      .where(@time_range_column => @time_range)
  end
end
