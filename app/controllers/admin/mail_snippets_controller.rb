class Admin::MailSnippetsController < Admin::BaseController
  include SortableTable

  before_action :find_snippet, except: [:index, :new, :create]

  def index
    @per_page = permitted_per_page(default: 25)
    @pagy, @mail_snippets = pagy(matching_mail_snippets.reorder("mail_snippets.#{sort_column} #{sort_direction}")
      .includes(:organization), limit: @per_page, page: permitted_page)
  end

  def show
    redirect_to edit_admin_mail_snippet_url(@mail_snippet)
  end

  def edit
    @organizations = Organization.all
  end

  def update
    if @mail_snippet.update(permitted_parameters)
      flash[:success] = "Snippet Saved!"
      redirect_to edit_admin_mail_snippet_url(@mail_snippet)
    else
      render action: :edit
    end
  end

  def new
    @mail_snippet = MailSnippet.new
    @organizations = Organization.all
  end

  def create
    @mail_snippet = MailSnippet.create(permitted_parameters)
    if @mail_snippet.save
      flash[:success] = "Snippet Created!"
      redirect_to edit_admin_mail_snippet_url(@mail_snippet)
    else
      render action: :new
    end
  end

  helper_method :matching_mail_snippets

  protected

  def sortable_columns
    %w[created_at organization_id updated_at kind]
  end

  def matching_mail_snippets
    return @matching_mail_snippets if defined?(@matching_mail_snippets)
    matching_mail_snippets = MailSnippet
    if MailSnippet.kinds.include?(params[:search_kind])
      @search_kind = params[:search_kind]
      matching_mail_snippets = matching_mail_snippets.where(kind: @search_kind)
    else
      @search_kind = "all"
    end
    if current_organization.present?
      matching_mail_snippets = matching_mail_snippets.where(organization_id: current_organization.id)
    end
    @matching_mail_snippets = matching_mail_snippets.where(created_at: @time_range)
  end

  def permitted_parameters
    params.require(:mail_snippet).permit(:kind,
      :subject,
      :organization_id,
      :body,
      :is_enabled,
      :latitude,
      :longitude,
      :proximity_radius,
      :doorkeeper_app_id,
      :is_location_triggered)
  end

  def find_snippet
    @mail_snippet = MailSnippet.find(params[:id])
  end
end
