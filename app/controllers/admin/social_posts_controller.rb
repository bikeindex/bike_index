class Admin::SocialPostsController < Admin::BaseController
  include SortableTable

  before_action :find_social_post, except: [:new, :create, :index]

  def index
    @per_page = permitted_per_page(default: 50)
    @pagy, @social_posts = pagy(:countish, matching_social_posts
      .includes(:social_account, :public_images, :stolen_record, :reposts, :original_post)
      .reorder(sort_column + " " + sort_direction), limit: @per_page, page: permitted_page)
  end

  def show
    if @social_post.imported_post?
      redirect_to edit_admin_social_post_path(params[:id])
      nil
    end
  end

  def edit
    unless @social_post.imported_post?
      redirect_to admin_social_post_path(params[:id])
      nil
    end
  end

  def update
    if @social_post.update(permitted_parameters)
      flash[:notice] = "Post saved!"
      redirect_to edit_admin_social_post_url
    else
      render action: :edit
    end
  end

  def new
    @social_post ||= SocialPost.new(kind: "app_post")
  end

  def create
    @social_post = SocialPost.new(permitted_parameters)
    if @social_post.kind == "imported_post"
      @social_post.social_account_id = nil
      @social_post.body = nil # Blank the attributes that may have been accidentally passed
      @social_post.platform_response = fetch_platform_response(@social_post.platform_id)
      @social_post.save
    elsif @social_post.kind == "app_post"
      @social_post.platform_id = nil
      @social_post.save
      if @social_post.id.present?
        @social_post.send_post
        repost_accounts.each { |social_account| @social_post.repost_to_account(social_account) }
      end
    else
      raise StandardError, "Don't know how to create post with kind: '#{@social_post.kind}'"
    end
    if @social_post.id.present?
      redirect_to edit_admin_social_post_url(id: @social_post.id)
    else
      flash[:error] ||= "Unable to create post"
      render action: :new
    end
  end

  def destroy
    if @social_post.present? && @social_post.destroy
      flash[:info] = "Post deleted."
      redirect_to admin_social_posts_url
    else
      flash[:error] = "Could not delete post."
      redirect_to edit_admin_social_post_url(@social_post.id)
    end
  end

  helper_method :matching_social_posts, :permitted_search_kinds

  private

  def earliest_period_date
    Time.at(1498672508) # First post
  end

  def sortable_columns
    %w[created_at social_account_id kind]
  end

  def permitted_search_kinds
    %w[all not_stolen] + SocialPost.kinds
  end

  def matching_social_posts
    social_posts = SocialPost
    social_posts = social_posts.not_repost unless Binxtils::InputNormalizer.boolean(params[:search_repost])
    @search_kind = permitted_search_kinds.include?(params[:search_kind]) ? params[:search_kind] : "all"
    social_posts = social_posts.public_send(@search_kind) unless @search_kind == "all"

    if params[:search_social_account_id].present?
      @social_account = SocialAccount.friendly_find(params[:search_social_account_id])
      social_posts = social_posts.where(social_account_id: @social_account.id) if @social_account.present?
    end
    social_posts = social_posts.admin_search(params[:query]) if params[:query].present?
    social_posts.where(created_at: @time_range)
  end

  def permitted_parameters
    params.require(:social_post).permit(:platform_id, :body_html, :image, :alignment, :body, :social_account_id,
      :remote_image_url, :remove_image, :kind)
  end

  def find_social_post
    @social_post ||= SocialPost.friendly_find(params[:id])
    return @social_post if @social_post.present?

    raise ActiveRecord::RecordNotFound
  end

  def fetch_platform_response(post_id)
    SocialAccount.default_account.get_post(post_id).as_json
  end

  def repost_accounts
    (params[:social_account_ids] || []).map { |id| SocialAccount.friendly_find(id) }
  end
end
