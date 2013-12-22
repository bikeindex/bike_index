module HeaderTagHelper

  def header_tags
    header_tag_hash = set_header_tag_hash
    html = title_tag_html(header_tag_hash)
    html << meta_tags_html(header_tag_hash)
    return html.html_safe
  end

protected

  def set_header_tag_hash
    special_meta_tags = ['bikes', 'welcome', 'blogs', 'users', 'manufacturers']
    if special_meta_tags.include? controller_name
      self.send("#{controller_name}_header_tags")
    else
      current_page_auto_hash
    end
  end
  
  def title_tag_html(hash)
    "<title>#{hash[:title_tag][:title]}</title>\n"
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
    base_description = t "meta_descriptions.base_description"
    tags = {
      :title_tag => { title: "Bike Index" },
      :meta_tags => {
        :charset           => "utf-8",
        :"X-UA-Compatible" => "IE=edge,chrome=1", 
        :viewport          => "width=device-width, initial-scale=1, maximum-scale=1",
        :description       => base_description
      }
    }
  end

  def current_page_auto_hash
    hash = default_hash
    title = t "meta_title.#{controller_name}_#{action_name}", default: "Blank"
    title = auto_title if title == "Blank"
    hash[:title_tag][:title] = title
    hash[:meta_tags][:description] = t "meta_descriptions.#{controller_name}_#{action_name}", default: "#{title} with the Bike Index"
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
    hash = default_hash
    if action_name == 'user_home' 
      hash[:title_tag][:title] = "Your bikes"
      hash[:title_tag][:title] = current_user.name if current_user.name.present?
    end
    hash
  end

  def bikes_header_tags
    hash = current_page_auto_hash
    if action_name == 'new'
      hash[:title_tag][:title] = t "meta_title.new_bike_stolen_#{@bike.stolen}"
      hash[:meta_tags][:description] = t "meta_descriptions.new_bike_stolen_#{@bike.stolen}"
    end
    if action_name == 'show'
      hash[:title_tag][:title] = "#{'Stolen ' if @bike.stolen }#{@bike.title_string}"
      hash[:meta_tags][:description] = "#{'Stolen ' if @bike.stolen }#{@bike.frame_colors.to_sentence} #{@bike.title_string}, serial: #{@bike.serial_number}"
    end
    if action_name == 'edit'
      hash[:title_tag][:title] = "Edit #{@bike.title_string}"
    end
    hash 
  end

  def users_header_tags
    hash = current_page_auto_hash
    if action_name == 'show'
      hash[:title_tag][:title] = @user.title if @user.title.present?
      hash[:meta_tags][:description] = "#{@user.title} on the Bike Index" if @user.title.present?
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

  def blogs_header_tags
    hash = current_page_auto_hash
    if action_name == 'show'
      hash[:title_tag][:title] = "#{@blog.title}"
      hash[:meta_tags][:description] = "#{@blog.body_abbr}"
    end
    hash
  end

end
