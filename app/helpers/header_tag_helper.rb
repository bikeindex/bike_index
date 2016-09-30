module HeaderTagHelper
  def header_tags
    # header_tag_hash = set_header_tag_hash
    # tags_hash = set_social_hash(header_tag_hash)
    # title_tag_html(tags_hash)
    # [
    #   title_tags,
    #   author_tag_html,
    #   meta_tags
    # ].compact.join("\n").html_safe
  end

  # Everything below here is an internal method

  SPECIAL_CONTROLLERS = %w(bikes welcome news users manufacturers organizations).freeze

  def header_tag_array
    return default_tags unless SPECIAL_META_TAG_CONTROLLERS.include? controller_name
    send("#{controller_name}_header_tags")
  end

  def page_title
    @page_title ||= strip_tags(auto_title)
  end

  def page_description
    @page_description ||= strip_tags(auto_description)
  end

  def translation_title
    t "meta_title.#{controller_name}_#{action_name}", default: ''
  end

  def translation_description
    t "meta_descriptions.#{controller_name}_#{action_name}", default: ''
  end

  def auto_title
    return translation_title if translation_title.present?
    case action_name
    when 'index'
      controller_name.humanize
    when 'new', 'edit', 'show', 'create'
      "#{auto_action_name_title} #{controller_name.humanize.singularize.downcase}"
    else
      action_name.humanize
    end
  end

  def auto_action_name_title
    {
      new: 'New',
      edit: 'Edit',
      show: 'View',
      create: 'Created'
    }.as_json.freeze[action_name]
  end

  def auto_description
    return translation_description if translation_description.present?
    'The best bike registry: Simple, secure and free.'
  end

  def default_meta_hash
    {
      'og:description'      => page_description,
      'twitter:description' => page_description,
      'og:title'            => page_title,
      'twitter:title'       => page_title,
      'og:url'              => request.url.to_s,
      'og:image'            => '/bike_index.png',
      'og:site_name'        => 'Bike Index',
      'twitter:card'        => 'summary',
      'twitter:creator'     => '@bikeindex',
      'twitter:site'        => '@bikeindex'
    }
  end

  def social_meta_content_tags(meta_hash)
    meta_hash.map { |k, v| content_tag(:meta, nil, content: v, property: k) }
  end

  def main_header_tags
    [
      tag(:meta, charset: 'utf-8'),
      tag(:meta, 'http-equiv' => 'Content-Language', content: 'en'),
      tag(:meta, 'http-equiv' => 'X-UA-Compatible', content: 'IE=edge'),
      tag(:meta, name: 'viewport', content: 'width=device-width'),
      content_tag(:title, page_title),
      tag(:meta, name: 'description', content: page_description),
      tag(:link, rel: 'shortcut icon', href: '/fav.ico'),
      tag(:link, rel: 'apple-touch-icon-precomposed apple-touch-icon', href: '/apple_touch_icon.png'),
      csrf_meta_tags
    ]
  end

  # def set_social_hash(hash)
  #   title = hash[:title_tag][:title]
  #   desc = hash[:meta_tags][:description]
  #   hash[:meta_tags][:"og:title"], hash[:meta_tags][:"twitter:title"] = title, title
  #   hash[:meta_tags][:"og:description"], hash[:meta_tags][:"twitter:description"] = desc, desc
  #   hash
  # end

  # def blog_tags
  # #   return '' unless controller_name == 'news' and action_name == 'show'
  # #   "<link rel='author' href='#{user_url(@blogger)}'/>"
  #   # = auto_discovery_link_tag(:atom, news_index_url(format: "atom"), { title: 'Bike Index news atom feed' })
  # end
  
  # def current_page_auto_hash
  #   hash = default_hash
  #   title = t("meta_title.#{controller_name}_#{action_name}", default: nil)
  #   title = auto_title if title == 'Blank'
  #   hash[:title_tag][:title] = title
  #   hash[:meta_tags][:description] = t("meta_descriptions.#{controller_name}_#{action_name}", default: "#{title} on the Bike Index"
  #   hash
  # end

  # def welcome_header_tags
  #   hash = current_page_auto_hash
  #   if action_name == 'user_home' 
  #     hash[:title_tag][:title] = 'Your bikes'
  #     hash[:title_tag][:title] = strip_tags(current_user.name) if current_user.name.present?
  #   end
  #   if action_name == 'choose_registration'
  #     hash[:title_tag][:title] = t 'meta_title.bikes_new'
  #     hash[:meta_tags][:description] = t 'meta_title.bikes_new'
  #   end
  #   hash
  # end

  # def bikes_header_tags
  #   hash = current_page_auto_hash
  #   if (action_name == 'new' || action_name == 'create') && current_user.present? && @bike.stolen
  #     hash[:title_tag][:title] = t 'meta_title.bikes_new_stolen'
  #     hash[:meta_tags][:description] = t 'meta_descriptions.bikes_new_stolen'
  #   end
  #   if action_name == 'edit' || action_name == 'update'
  #     if @edit_templates.present?
  #       hash[:title_tag][:title] = "#{@edit_templates[@edit_template]} - #{@bike.title_string}"
  #     else
  #       hash[:title_tag][:title] = "Edit #{@bike.title_string}"
  #     end
  #   end
  #   if action_name == 'show'
  #     hash[:title_tag][:title] = "#{'Stolen ' if @bike.stolen }#{@bike.title_string}"
  #     hash[:meta_tags][:description] =  "#{@bike.frame_colors.to_sentence} #{@bike.title_string}, serial: #{@bike.serial_number}. #{@bike.stolen_string}#{@bike.description}"
  #     if @bike.thumb_path.present? && @bike.public_images.present?
  #       iurl = @bike.public_images.first.image_url
  #     elsif @bike.stock_photo_url.present?
  #       iurl = @bike.stock_photo_url
  #     end
  #     if iurl.present?
  #       hash[:meta_tags][:"twitter:card"] = "summary_large_image"
  #       hash[:meta_tags][:"og:image"] = iurl
  #       hash[:meta_tags][:"twitter:image"] = iurl
  #     end
  #     if @bike.owner && @bike.owner.show_twitter && @bike.owner.twitter.present?
  #       hash[:meta_tags][:"twitter:creator"] = "@#{@bike.owner.twitter}"
  #     end
  #   end
  #   hash
  # end

  # def users_header_tags
  #   hash = current_page_auto_hash
  #   if action_name == 'show'
  #     hash[:title_tag][:title] = @user.title if @user.title.present?
  #     hash[:meta_tags][:description] = "#{@user.title} on the Bike Index" if @user.title.present?
  #     hash[:meta_tags][:"og:image"] = @user.avatar.url unless @user.avatar.url(:medium) == "https://files.bikeindex.org/blank.png"
  #   end
  #   if action_name == 'edit'
  #     hash[:title_tag][:title] = "Edit your account"
  #   end
  #   hash
  # end

  # def manufacturers_header_tags
  #   hash = current_page_auto_hash
  #   if action_name == 'show'
  #     hash[:title_tag][:title] = "#{@manufacturer.name}"
  #     hash[:meta_tags][:description] = "#{@manufacturer.name} on the Bike Index."
  #   end
  #   hash
  # end

  # def news_header_tags
  #   hash = current_page_auto_hash
  #   if action_name == 'show'
  #     hash[:title_tag][:title] = @blog.title
  #     hash[:meta_tags][:description] = @blog.description
  #     hash[:meta_tags][:"og:type"] = "article"
  #     hash[:meta_tags][:"og:published_time"] = @blog.published_at.utc
  #     hash[:meta_tags][:"og:modified_time"] = @blog.updated_at.utc
  #     hash[:meta_tags][:"twitter:creator"] = "@#{@blog.user.twitter}" if @blog.user.twitter

  #     if @blog.index_image.present?
  #       hash[:meta_tags][:"twitter:card"] = "summary_large_image"
  #       hash[:meta_tags][:"og:image"] = @blog.index_image_lg
  #       hash[:meta_tags][:"twitter:image"] = @blog.index_image_lg
  #     elsif @blog.public_images.any?
  #       hash[:meta_tags][:"twitter:card"] = "summary_large_image"
  #       hash[:meta_tags][:"og:image"] = @blog.public_images.last.image_url 
  #       hash[:meta_tags][:"twitter:image"] = @blog.public_images.last.image_url 
  #     end
  #   end
  #   hash
  # end

end
