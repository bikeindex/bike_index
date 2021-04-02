class Admin::ContentTagsController < Admin::BaseController
  before_action :find_content_tag, only: %i[edit update]

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 100
    @content_tags = matching_content_tags
      .order(sort_column + " " + sort_direction)
      .page(page).per(per_page)
  end

  def new
    @content_tag ||= ContentTag.new
  end

  def show
    redirect_to edit_admin_content_tag_path
  end

  def edit
  end

  def new
  end

  def update
    @content_tag.update_attributes(permitted_update_parameters)
    flash[:success] = "Tag updated" unless flash[:error].present?
    redirect_to admin_content_tags_path
  end

  def create
    @content_tag = ContentTag.new(permitted_update_parameters)
    if @content_tag.save
      flash[:success] = "Tag created"
      redirect_to admin_content_tags_path
    else
      flash[:error] = "Unable to create"
      render :new
    end
  end

  helper_method :matching_content_tags

  protected

  def sortable_columns
    %w[name created_at organization_id kind updated_at user_id resolved_at]
  end

  def matching_content_tags
    ContentTag
  end

  def permitted_update_parameters
    params.require(:content_tag).permit(:name, :priority)
  end

  def find_content_tag
    @content_tag = ContentTag.find(params[:id])
  end
end
