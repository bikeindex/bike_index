# frozen_string_literal: true

class Admin::EmailDomainsController < Admin::BaseController
  include SortableTable
  before_action :find_email_domain, only: %i[show update]

  def index
    @per_page = params[:per_page] || 25

    @pagy, @email_domains = pagy(
      matching_email_domains.includes(:creator).reorder("email_domains.#{sort_column} #{sort_direction}"),
      limit: @per_page
    )
  end

  def new
    @email_domain = EmailDomain.new
  end

  def create
    @email_domain = EmailDomain.new(email_domain_params)
    @email_domain.creator = current_user

    if EmailDomain.allow_creation?(@email_domain.domain)
      if @email_domain.save
        flash[:success] = "New email domain created"
        redirect_to admin_email_domains_url and return
      else
        flash.now[:error] = @email_domain.errors.full_messages.to_sentence
      end
    else
      flash.now[:error] = "Doesn't seem like a new spam email domain - " \
        "not enough users with the domain or too many bikes have the domain"
    end
    render :new
  end

  def show
  end

  def edit
    redirect_to admin_email_domain_path
  end

  def update
  end

  private

  def sortable_columns
    %w[created_at updated_at domain creator_id status]
  end

  def find_email_domain
    @email_domain = EmailDomain.find(params[:id])
  end

  def matching_email_domains
    email_domains = EmailDomain
    @show_matching_users = InputNormalizer.boolean(params[:search_matching_users])
    @time_range_column = sort_column if %w[updated_at].include?(sort_column)
    @time_range_column ||= "created_at"

    email_domains.where(@time_range_column => @time_range)
  end

  def email_domain_params
    params.require(:email_domain).permit(:domain)
  end
end
