class NewsController < ApplicationController
  layout 'application_revised'

  def show
    @blog = Blog.find_by_title_slug(params[:id])
    @blog = Blog.find_by_old_title_slug(params[:id]) unless @blog
    @blog = Blog.find(params[:id]) unless @blog
    unless @blog
      raise ActionController::RoutingError.new('Not Found')
    end
    if @blog.is_listicle
      @page = params[:page].to_i 
      @page = 1 unless @page > 0
      @list_item = @blog.listicles[@page-1]
      @next_item = true unless @page >= @blog.listicles.count
      @prev_item = true unless @page == 1
    end
    @blogger = @blog.user
  end

  def index
    @blogs = Blog.published
  end
end
