class Admin::NewsController < Admin::BaseController
  before_filter :find_blog, only: [:show, :edit, :update, :destroy]
  before_filter :set_dignified_name

  def index
    @blogs = Blog.order("created_at asc")
  end

  def new
    @blog = Blog.new(published_at: Time.now, user_id: current_user.id)
  end

  def image_edit
    @listicle = Listicle.find(params[:id])
    @blog = @listicle.blog
  end

  def show
    redirect_to edit_admin_news_url
  end

  def edit
  end

  def update
    body = "blog"
    title = params[:blog][:title]
    body = params[:blog][:body]
    if @blog.update_attributes(permitted_parameters)
      @blog.reload
      if @blog.listicles.present?
        @blog.listicles.pluck(:id).each { |id| ListicleImageSizeWorker.perform_in(1.minutes, id) }
      end
      flash[:success] = "Blog saved!"
      redirect_to edit_admin_news_url(@blog)
    else
      render action: :edit
    end
  end

  def create
    @blog = Blog.create({
      title: params[:blog][:title],
      user_id: current_user.id,
      body: "No content yet, write some now!",
      published_at: Time.now,
      is_listicle: false
    })
    if @blog.save
      flash[:success] = "Blog created!"
      redirect_to edit_admin_news_url(@blog)
    else
      flash[:error] = "Blog error! #{@blog.errors.full_messages.to_sentence}"
      redirect_to new_admin_news_path
    end
  end

  def destroy
    @blog.destroy
    redirect_to admin_news_index_url
  end

  protected

  def permitted_parameters
    params.require(:blog).permit(*%w(title body user_id published_at post_date post_now tags published old_title_slug
       timezone description_abbr update_title is_listicle listicles_attributes user_email index_image_id index_image).map(&:to_sym).freeze)
  end

  def set_dignified_name
    @dignified_name = "short form creative non-fiction"
    @dignified_name = "collection of vignettes" if @blog && @blog.is_listicle
  end

  def find_blog
    @blog = Blog.find_by_title_slug(params[:id])
  end
end
