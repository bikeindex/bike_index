class NewsController < ApplicationController
  def index
    @blogs = Blog.published.blog.in_language(params[:language])
    redirect_to news_index_url(format: "atom") if request.format == "xml"
  end

  def show
    @blog = Blog.friendly_find(params[:id])

    unless @blog
      raise ActionController::RoutingError.new("Not Found")
    end

    if @blog.info?
      redirect_to info_path(@blog.to_param) and return
    end

    if @blog.is_listicle
      @page = params[:page].to_i
      @page = 1 unless @page > 0
      @list_item = @blog.listicles[@page - 1]
      @next_item = true unless @page >= @blog.listicles.count
      @prev_item = true unless @page == 1
    end

    @blogger = @blog.user
  end
end
