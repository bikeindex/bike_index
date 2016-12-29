module HeaderTagHelper
  def header_tags
    header_tag_array.compact.join("\n").html_safe
  end

  # Everything below here is an internal method, not private for testing purposes

  def header_tag_array
    return default_header_tag_array unless !controller_namespace && SPECIAL_CONTROLLERS.include?(controller_name)
    send("#{controller_name}_header_tags")
  end

  def page_title=(val)
    @page_title = strip_tags(val).strip
  end

  def page_description=(val)
    @page_description = strip_tags(val).strip
  end

  def page_title
    @page_title || self.page_title = auto_title
  end

  attr_writer :page_image

  def page_image
    @page_image ||= DEFAULT_IMAGE
  end

  def page_description
    @page_description || self.page_description = auto_description
  end

  def auto_title
    return translation_title if translation_title.present?
    [auto_namespace_title, auto_controller_and_action_title].compact.join(' ')
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
      'og:image'            => page_image,
      'twitter:image'       => page_image,
      'og:site_name'        => 'Bike Index',
      'fb:app_id'           => '223376277803071',
      'twitter:card'        => (page_image == DEFAULT_IMAGE ? 'summary' : 'summary_large_image'),
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

  def welcome_header_tags
    if action_name == 'user_home'
      self.page_title = (current_user && current_user.name) ? "#{current_user.name} on Bike Index" : 'Your bikes'
    elsif action_name == 'choose_registration'
      self.page_title = translation_title(location: 'meta_titles.bikes_new')
      self.page_description = translation_description(location: 'meta_descriptions.bikes_new')
    end
    default_header_tag_array
  end

  def bikes_header_tags
    meta_overrides = {}
    if (action_name == 'new' || action_name == 'create') && @bike.stolen
      self.page_title = translation_title(location: 'meta_titles.bikes_new_stolen')
      self.page_description = translation_description(location: 'meta_descriptions.bikes_new_stolen')
    elsif action_name == 'edit' || action_name == 'update'
      if @edit_templates.present?
        self.page_title = "#{@edit_templates[@edit_template]} - #{@bike.title_string}"
      else
        self.page_title = "Edit #{@bike.title_string}"
      end
    elsif action_name == 'show'
      self.page_title = "#{'Stolen ' if @bike.stolen}#{@bike.title_string}"
      self.page_description = "#{@bike.frame_colors.to_sentence} #{@bike.title_string}, serial: #{@bike.serial_number}. #{@bike.stolen_string}#{@bike.description}"
      if @bike.thumb_path.present? && @bike.public_images.present?
        self.page_image = @bike.public_images.first.image_url
      elsif @bike.stock_photo_url.present?
        self.page_image = @bike.stock_photo_url
      end
      if @bike.owner && @bike.owner.show_twitter && @bike.owner.twitter.present?
        meta_overrides['twitter:creator'] = "@#{@bike.owner.twitter}"
      end
    end
    default_header_tag_array(meta_overrides)
  end

  def landing_pages_header_tags
    if current_organization
      args = { default: '', organization: current_organization.short_name }
      self.page_title = translation_title(translation_args: args)
      self.page_description = translation_description(translation_args: args)
    end
    default_header_tag_array
  end

  def users_header_tags
    if action_name == 'show'
      if @user.title.present?
        self.page_title = @user.title
        self.page_description = "#{@user.title} on Bike Index"
      end
      if @user.avatar && @user.avatar.url != 'https://files.bikeindex.org/blank.png'
        self.page_image = @user.avatar.url
      end
    end
    default_header_tag_array
  end

  def news_header_tags
    return default_header_tag_array + [news_auto_discovery_link] unless action_name == 'show'
    self.page_title = @blog.title
    self.page_description = @blog.description
    meta_overrides = {
      'og:type' => 'article',
      'og:published_time' => @blog.published_at.utc,
      'og:modified_time' => @blog.updated_at.utc
    }
    meta_overrides['twitter:creator'] = "@#{@blog.user.twitter}" if @blog.user.twitter
    if @blog.index_image.present?
      self.page_image = @blog.index_image_lg
    elsif @blog.public_images.any?
      self.page_image = @blog.public_images.last.image_url
    end
    default_header_tag_array(meta_overrides) +
      [news_auto_discovery_link, tag(:link, rel: 'author', href: user_url(@blog.user))]
  end

  private

  SPECIAL_CONTROLLERS = %w(bikes welcome news users landing_pages).freeze
  DEFAULT_IMAGE = '/bike_index.png'.freeze

  def default_header_tag_array(meta_overrides = {})
    social_meta_content_tags(default_meta_hash.merge(meta_overrides)) + main_header_tags
  end

  def default_translation_args
    return { default: '' } unless controller_namespace == 'organized'
    { default: '', organization: current_organization.short_name }
  end

  def translation_title(location: nil, translation_args: default_translation_args)
    location ||= "meta_titles.#{page_id}"
    t(location, translation_args)
  end

  def translation_description(location: nil, translation_args: default_translation_args)
    location ||= "meta_descriptions.#{page_id}"
    t(location, translation_args)
  end

  def auto_controller_and_action_title
    case action_name
    when 'index'
      controller_name.humanize
    when 'new', 'edit', 'show', 'create'
      "#{auto_action_name_title} #{controller_name.humanize.singularize.downcase}"
    else
      action_name.humanize
    end
  end

  def auto_namespace_title
    if controller_namespace == 'admin'
      'Admin |'
    elsif controller_namespace == 'organized'
      current_organization.short_name
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

  def news_auto_discovery_link
    auto_discovery_link_tag(:atom, news_index_url(format: 'atom'), title: 'Bike Index news atom feed')
  end
end
