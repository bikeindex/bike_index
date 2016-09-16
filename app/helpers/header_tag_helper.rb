module HeaderTagHelper

  def header_tags
    header_tag_hash = set_header_tag_hash
    header_tag_hash = set_social_hash(header_tag_hash)
    html = title_tag_html(header_tag_hash)
    html << author_tag_html
    html << meta_tags_html(header_tag_hash)
    return html.html_safe
  end

protected

  def set_header_tag_hash
    special_meta_tags = %w(bikes welcome news users manufacturers organizations)
    if sub_module_name == 'organized_'
      self.send(:organizations_header_tags)
    elsif special_meta_tags.include? controller_name
      self.send("#{controller_name}_header_tags")
    else
      current_page_auto_hash
    end
  end
  
  def title_tag_html(hash)
    "<title lang='en'>#{(@page_title ? @page_title : hash[:title_tag][:title])}</title>\n"
  end

  def set_social_hash(hash)
    title = hash[:title_tag][:title]
    desc = hash[:meta_tags][:description]
    hash[:meta_tags][:"og:title"], hash[:meta_tags][:"twitter:title"] = title, title
    hash[:meta_tags][:"og:description"], hash[:meta_tags][:"twitter:description"] = desc, desc
    hash
  end


  def author_tag_html
    return '' unless controller_name == 'news' and action_name == 'show'
    "<link rel='author' href='#{user_url(@blogger)}'/>"
  end

  def meta_tags_html(hash)
    html = ""
    hash[:meta_tags].each do |k,value_or_array|
      values = value_or_array.is_a?(Array) ? value_or_array : [value_or_array]
      values.each do |v|
        if k.to_s =~ /[a-zA-Z_][-a-zA-Z0-9_.]\:/
          html << "<meta property=\"#{h(k)}\" content=\"#{h(v)}\" />\n"  
        else
          html << "<meta name=\"#{h(k)}\" content=\"#{h(v)}\" />\n"  
        end
      end
    end
    html
  end

  def default_hash
    base_description = t 'meta_descriptions.welcome_index'
    tags = {
      meta_tags: {
        charset:           'utf-8',
        :'X-UA-Compatible' => 'IE=edge,chrome=1', 
        viewport:          'width=device-width, initial-scale=1, maximum-scale=1',
        description:       base_description,
        :'og:url'          => "#{request.url}",
        :'og:image'        => '/bike_index.png',
        :'og:site_name'    => 'Bike Index',
        :'twitter:card'    => 'summary',
        :'twitter:creator' => '@bikeindex',
        :'twitter:site'    => '@bikeindex'
      },
      title_tag: { title: 'Bike Index' }
    }
  end

  def current_page_auto_hash
    hash = default_hash
    title = t "meta_title.#{controller_name}_#{action_name}", default: 'Blank'
    title = auto_title if title == 'Blank'
    hash[:title_tag][:title] = title
    hash[:meta_tags][:description] = t "meta_descriptions.#{controller_name}_#{action_name}", default: "#{title} on the Bike Index"
    hash
  end

  def auto_title
    title = case action_name
    when 'index'
      controller_name.humanize
    when 'new'
      "New #{controller_name.humanize.singularize.downcase}"
    when 'edit'
      "Edit #{controller_name.humanize.singularize.downcase}"
    when 'show'
      "View #{controller_name.humanize.singularize.downcase}"
    else
      action_name.humanize
    end
  end

  def welcome_header_tags
    hash = current_page_auto_hash
    if action_name == 'user_home' 
      hash[:title_tag][:title] = 'Your bikes'
      hash[:title_tag][:title] = strip_tags(current_user.name) if current_user.name.present?
    end
    if action_name == 'choose_registration'
      hash[:title_tag][:title] = t 'meta_title.bikes_new'
      hash[:meta_tags][:description] = t 'meta_title.bikes_new'
    end
    hash
  end

  def bikes_header_tags
    hash = current_page_auto_hash
    if (action_name == 'new' || action_name == 'create') && current_user.present? && @bike.stolen
      hash[:title_tag][:title] = t 'meta_title.bikes_new_stolen'
      hash[:meta_tags][:description] = t 'meta_descriptions.bikes_new_stolen'
    end
    if action_name == 'edit' || action_name == 'update'
      if @edit_templates.present?
        hash[:title_tag][:title] = "#{@edit_templates[@edit_template]} - #{@bike.title_string}"
      else
        hash[:title_tag][:title] = "Edit #{@bike.title_string}"
      end
    end
    if action_name == 'show'
      hash[:title_tag][:title] = "#{'Stolen ' if @bike.stolen }#{@bike.title_string}"
      hash[:meta_tags][:description] =  "#{@bike.frame_colors.to_sentence} #{@bike.title_string}, serial: #{@bike.serial_number}. #{@bike.stolen_string}#{@bike.description}"
      if @bike.thumb_path.present? && @bike.public_images.present?
        iurl = @bike.public_images.first.image_url
      elsif @bike.stock_photo_url.present?
        iurl = @bike.stock_photo_url
      end
      if iurl.present?
        hash[:meta_tags][:"twitter:card"] = "summary_large_image"
        hash[:meta_tags][:"og:image"] = iurl
        hash[:meta_tags][:"twitter:image"] = iurl
      end
      if @bike.owner && @bike.owner.show_twitter && @bike.owner.twitter.present?
        hash[:meta_tags][:"twitter:creator"] = "@#{@bike.owner.twitter}"
      end
    end
    hash
  end

  def organizations_header_tags
    hash = default_hash
    title = auto_title
    hash[:title_tag][:title] = title
    hash
  end

  def users_header_tags
    hash = current_page_auto_hash
    if action_name == 'show'
      hash[:title_tag][:title] = @user.title if @user.title.present?
      hash[:meta_tags][:description] = "#{@user.title} on the Bike Index" if @user.title.present?
      hash[:meta_tags][:"og:image"] = @user.avatar.url unless @user.avatar.url(:medium) == "https://files.bikeindex.org/blank.png"
    end
    if action_name == 'edit'
      hash[:title_tag][:title] = "Edit your account"
    end
    hash
  end

  def manufacturers_header_tags
    hash = current_page_auto_hash
    if action_name == 'show'
      hash[:title_tag][:title] = "#{@manufacturer.name}"
      hash[:meta_tags][:description] = "#{@manufacturer.name} on the Bike Index."
    end
    hash
  end

  def news_header_tags
    hash = current_page_auto_hash
    if action_name == 'show'
      hash[:title_tag][:title] = @blog.title
      hash[:meta_tags][:description] = @blog.description
      hash[:meta_tags][:"og:type"] = "article"
      hash[:meta_tags][:"og:published_time"] = @blog.published_at.utc
      hash[:meta_tags][:"og:modified_time"] = @blog.updated_at.utc
      hash[:meta_tags][:"twitter:creator"] = "@#{@blog.user.twitter}" if @blog.user.twitter

      if @blog.index_image.present?
        hash[:meta_tags][:"twitter:card"] = "summary_large_image"
        hash[:meta_tags][:"og:image"] = @blog.index_image_lg
        hash[:meta_tags][:"twitter:image"] = @blog.index_image_lg
      elsif @blog.public_images.any?
        hash[:meta_tags][:"twitter:card"] = "summary_large_image"
        hash[:meta_tags][:"og:image"] = @blog.public_images.last.image_url 
        hash[:meta_tags][:"twitter:image"] = @blog.public_images.last.image_url 
      end
    end
    hash
  end

end
