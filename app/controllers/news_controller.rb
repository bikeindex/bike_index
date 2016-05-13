=begin
*****************************************************************
* File: app/controllers/news_controller.rb 
* Name: Class NewsController 
* Set some methods to news controllers
*****************************************************************
=end

class NewsController < ApplicationController
  layout 'content'
  before_filter :set_blogs_activeSection
  before_filter :set_revised_layout

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
      @listItem = @blog.listicles[@page-1]
      @nextItem = true unless @page >= @blog.listicles.count
      @prevItem = true unless @page == 1
    else
      #nothing to do
    end      
    @blogger = @blog.user
  end

  def index
    @blogs = Blog.published
  end

  def set_blogs_activeSection
    @activeSection = "about"
  end
end
