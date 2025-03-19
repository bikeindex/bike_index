# frozen_string_literal: true

class Admin::EmailDomainsController < Admin::BaseController
  include SortableTable
  before_action :find_email_domain, only: %i[show update]
  helper_method :searchable_statuses, :matching_email_domains, :ignorable_options

  def index
    @per_page = params[:per_page] || 25

    @pagy, @email_domains = pagy(ordered_email_domains, limit: @per_page)
  end

  def new
    @email_domain = EmailDomain.new
  end

  def create
    @email_domain = EmailDomain.new(email_domain_params)
    @email_domain.creator = current_user

    if @email_domain.save
      @email_domain.process!
      flash[:success] = "New email domain created"
      redirect_to admin_email_domains_url and return
    else
      flash.now[:error] = @email_domain.errors.full_messages.to_sentence
    end
    render :new
  end

  def show
    @subdomains = @email_domain.calculated_subdomains
    unless @email_domain.tld_matches_subdomains?
      @matching_tld = EmailDomain.find_matching_domain(@email_domain.tld)
    end
  end

  def edit
    redirect_to admin_email_domain_path
  end

  def update
    # Only check if allowed to make banned if updating to make banned
    if permitted_update_parameters[:status] == "banned" && !@email_domain.banned? && @email_domain.has_ban_blockers?
      flash.now[:error] = domain_ban_message(@email_domain)
    else
      @email_domain.creator_id ||= current_user.id
      @email_domain.data["no_auto_assign_status"] = true
      if @email_domain.update(permitted_update_parameters)
        flash[:success] = "Domain Saved!"
        @email_domain.reload.process!
        redirect_to admin_email_domain_url(@email_domain) and return
      else
        flash[:error] = @email_domain.errors.full_messages
      end
    end

    render action: :show
  end

  private

  def sortable_columns
    %w[created_at updated_at domain creator_id status user_count bike_count status_changed_at
      spam_score domain_length]
  end

  def searchable_statuses
    EmailDomain.statuses.keys.map(&:to_s) + %w[ban_or_provisional]
  end

  def ordered_email_domains
    order_sql = if sort_column == "bike_count"
      Arel.sql("COALESCE((data -> 'bike_count')::integer, 0) #{sort_direction}")
    elsif sort_column == "spam_score"
      Arel.sql("COALESCE((data -> 'spam_score')::integer, 0) #{sort_direction}")
    elsif sort_column == "domain"
      Arel.sql("REVERSE(domain) #{sort_direction}")
    elsif sort_column == "domain_length"
      Arel.sql("LENGTH(domain) ASC")
    else
      "email_domains.#{sort_column} #{sort_direction}"
    end
    matching_email_domains.includes(:creator).reorder(order_sql)
  end

  def find_email_domain
    @email_domain = EmailDomain.find(params[:id])
  end

  def matching_email_domains
    email_domains = EmailDomain
    @status = searchable_statuses.include?(params[:search_status]) ? params[:search_status] : nil
    email_domains = @status.present? ? email_domains.send(@status) : email_domains.not_ignored
    if params[:query].present?
      email_domains = email_domains.where("domain ILIKE ?", "%#{params[:query]}%")
    end
    if params[:search_tld].present?
      @tld = params[:search_tld]
      email_domains = (@tld == "only_tld") ? email_domains.tld : email_domains.subdomain
    end

    @show_matching_users = InputNormalizer.boolean(params[:search_matching_users])
    @time_range_column = sort_column if %w[updated_at status_changed_at].include?(sort_column)
    @time_range_column ||= "created_at"

    email_domains.where(@time_range_column => @time_range)
  end

  def earliest_period_date
    Time.at(1735711200) # 2025-01-1
  end

  def permitted_update_parameters
    params.require(:email_domain).permit(:status)
  end

  def email_domain_params
    params.require(:email_domain).permit(:domain)
  end

  def domain_ban_message(email_domain)
    "Doesn't seem like a new spam email domain" + if email_domain.calculated_bikes.count > 0
      " - Maybe there are bikes"
    else
      ""
    end
  end
end
