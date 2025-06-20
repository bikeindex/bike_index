# frozen_string_literal: true

module HeaderTags
  class Component < ApplicationComponent
    DEFAULT_IMAGE = "/opengraph.png"
    DEFAULT_TWITTER = "@bikeindex"

    def initialize(controller_name:, action_name:, request_url:, page_title: nil, page_obj: nil, updated_at: nil, organization_name: nil, controller_namespace: nil)
      # TODO: Do any pages need a query string?
      @page_url = request_url.split("?").first

      # TODO: Don't actually need to store @page_key, it's just for page_json_ld
      @page_key = translation_key_for(controller_namespace:, controller_name:, action_name:, page_obj:)
      @display_auto_discovery = controller_name == "news"

      @page_title = page_title

      if page_obj.is_a?(Bike) || page_obj.is_a?(BikeVersion)
        assign_bike_attrs(page_obj, action_name)
      elsif page_obj.is_a?(Blog)
        assign_blog_attrs(page_obj)
      elsif @page_key == "users_show"
        assign_user_attrs(page_obj)
      end

      @page_title ||= translation_if_exists("meta_titles.#{@page_key}", organization_name) ||
        auto_title_for(controller_name:, controller_namespace:, action_name:, organization_name:)
      @page_description ||= translation_if_exists("meta_descriptions.#{@page_key}", organization_name) ||
        default_description
    end

    private

    def default_description
      I18n.t("meta_descriptions.welcome_index")
    end

    def page_image
      @page_image || DEFAULT_IMAGE
    end

    def twitter_image
      @twitter_image || page_image
    end

    def facebook_image
      @facebook_image || page_image
    end

    def twitter_creator
      @twitter_creator || DEFAULT_TWITTER
    end

    def known_image_dimensions?
      facebook_image == DEFAULT_IMAGE || @image_dimensions.present?
    end

    def image_width
      @image_dimensions&.first || 1200 # default image is 1200
    end

    def image_height
      @image_dimensions&.last || 630 # default image is 630
    end

    def og_updated_property
      (@meta_type == "article") ? "article:modified_time" : "og:updated_time"
    end

    def url_canonical
      @url_canonical || @page_url
    end

    def page_json_ld
      # ... eventually might want to use Vehicle, but currently would use no properties
      json_ld_type = if @meta_type == "article"
        (@page_key == "news_show") ? "BlogPosting" : "Article"
      else
        "WebPage"
      end
      {
        "@context" => "http://schema.org",
        "@type" => json_ld_type,
        "image" => page_image,
        "url" => @page_url,
        "headline" => @page_title,
        "alternativeHeadline" => (@secondary_title.present? ? @secondary_title : @page_description)
      }.merge(@published_at.present? ? {"datePublished" => @published_at} : {})
        .merge(@updated_at.present? ? {"dateModified" => @updated_at} : {})
    end

    def date(datetime = nil)
      datetime&.strftime("%Y-%m-%d") # Verify 8601
    end

    def time(datetime = nil)
      datetime&.utc&.iso8601(0)
    end

    #
    #
    # Translation and auto assign methods
    #

    def translation_key_for(controller_namespace:, controller_name:, action_name:, page_obj:)
      return "bikes_new" if controller_name == "welcome" && action_name == "choose_registration"

      if %w[bikes bike_versions].include?(controller_name)
        return "bikes_new_stolen" if (action_name == "new" || action_name == "create") && page_obj&.status_stolen?
      elsif %w[embed embed_extended embed_create_success].include?(action_name)
        # All the registration embed forms have the same title and description
        controller_name = "registrations"
        action_name = "embed"
      end

      [controller_namespace, controller_name, action_name].compact.join("_")
    end

    # Check I18n.exists first - otherwise translation throws an error
    def translation_if_exists(key, organization_name)
      I18n.exists?(key) ? I18n.t(key, organization: organization_name) : nil
    end

    def auto_title_for(controller_name:, controller_namespace:, action_name:, organization_name:)
      namespace_title = if controller_namespace == "admin"
        "🧰"
      elsif controller_namespace == "organized"
        organization_name
      end

      [
        namespace_title,
        auto_controller_and_action_title(controller_name, action_name)
      ].compact.join(" ")
    end

    def auto_controller_and_action_title(controller_name, action_name)
      case action_name
      when "index"
        controller_name.humanize
      when "new", "edit", "show", "create"
        "#{auto_action_name_title(action_name)} #{controller_name.humanize.singularize.downcase}"
      else
        action_name.humanize
      end
    end

    def auto_action_name_title(action_name)
      {
        new: "New",
        edit: "Edit",
        show: "View",
        create: "Created"
      }.as_json.freeze[action_name]
    end

    #
    #
    # Below here is page type specific assignment
    #

    def assign_blog_attrs(blog)
      @updated_at = time(blog.updated_at)
      @published_at = time(blog.updated_at)
      @meta_type = "article"
      @page_title ||= blog.title
      @page_description ||= blog.description
      @secondary_title = blog.secondary_title if blog.secondary_title.present?
      @page_image = if blog.index_image.present?
        blog.index_image_lg
      elsif blog.public_images.any?
        blog.public_images.last.image_url
      end
      @url_canonical = blog.canonical_url if blog.canonical_url?
      return unless blog.user.present?

      @twitter_creator = "@#{blog.user.twitter}" if blog.user.twitter
      @author = "/users/#{blog.user&.to_param}"
    end

    def assign_bike_attrs(bike, action_name)
      @updated_at = time(bike&.updated_at)
      return unless action_name == "show"

      status_prefix = bike.status_with_owner? ? "" : bike.status_humanized.titleize
      @page_title ||= [status_prefix, bike.title_string].compact.join(" ")

      @page_description = bike_page_description(bike, status_prefix)

      if (header_image_urls = BikeServices::Displayer.header_image_urls(bike))
        @image_dimensions = [1200, 630]
        @page_image = header_image_urls[:facebook]
        @facebook_image = header_image_urls[:facebook]
        @twitter_image = header_image_urls[:twitter]
      end

      if bike.owner&.show_twitter && bike.owner.twitter.present?
        @twitter_creator = "@#{bike.owner.twitter}"
      end
    end

    def bike_page_description(bike, status_prefix)
      special_status_string = if bike.is_a?(BikeVersion)
        [
          "Version",
          bike.start_at.present? ? "from: #{date(bike.start_at)}" : nil,
          bike.end_at.present? ? "to: #{date(bike.end_at)}" : nil
        ].compact.join(" ")
      elsif bike.status_stolen? && bike.current_stolen_record.present?
        "#{status_prefix}: #{date(bike.current_stolen_record.date_stolen)}, from: #{bike.current_stolen_record.address(country: [:iso])}"
      elsif bike.current_impound_record.present?
        "#{status_prefix}: #{date(bike.current_impound_record.impounded_at)}, in: #{bike.current_impound_record.address(country: [:iso, :optional])}"
      end

      # Don't show serial on bike versions
      serial_display = bike.is_a?(Bike) ? ", serial: #{bike.serial_display}" : ""

      [
        "#{bike.frame_colors.to_sentence} #{bike.title_string}#{serial_display}.",
        (bike.description.present? ? "#{bike.description}." : nil),
        special_status_string
      ].compact.join(" ")
    end

    def assign_user_attrs(user)
      @page_title = InputNormalizer.sanitize(user.name) if user.name.present?
      @page_description = "Bike Index user account: #{user.title}" if user.title.present?

      if user.avatar && user.avatar.url != "https://files.bikeindex.org/blank.png"
        @page_image = user.avatar.url
      end
    end
  end
end
