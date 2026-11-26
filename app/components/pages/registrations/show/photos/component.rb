# frozen_string_literal: true

module Pages
  module Registrations
    module Show
      module Photos
        class Component < ApplicationComponent
          def initialize(bike:, owner: false, title: nil, subtitle: nil)
            @bike = bike
            @owner = owner
            @title = title
            @subtitle = subtitle
          end

          private

          # Along the bottom of the hero photo: its stock photo badge, above the title and
          # subtitle on a gradient (mobile only - on desktop the title lives in the summary column)
          def hero_overlay(badge = nil)
            title = hero_title
            return if badge.blank? && title.blank?

            content_tag(:div, safe_join([badge, title].compact), class: "tw:pointer-events-none tw:absolute tw:inset-x-0 tw:bottom-0")
          end

          def hero_title
            return if @title.blank?

            parts = [content_tag(:h2, @title, class: "tw:text-xl tw:font-bold tw:text-white tw:leading-tight")]
            parts << content_tag(:p, @subtitle, class: "tw:mt-0.5 tw:text-sm tw:text-white/85") if @subtitle.present?

            content_tag(:div, safe_join(parts), class: "tw:bg-gradient-to-t tw:from-black/60 tw:to-transparent tw:px-2 tw:py-4 tw:lg:hidden")
          end

          # The gallery's starts hidden, as it opens on the vehicle's own photo
          def stock_badge(gallery: false)
            tag.div(render(Atoms::StockPhotoBadge::Component.new(bike: @bike)),
              class: ["tw:px-2 tw:pb-2", ("tw:hidden" if gallery)],
              data: ({"registrations--show--photos-target": "stockBadge"} if gallery))
          end

          def bike_image_url
            @bike.image_url(:large) # corrects the URL for remote images in development
          end

          def bike_image_original_url
            @bike.image_url # original, un-resized
          end

          def bike_image
            @bike.public_images.first
          end

          def thumbnail_images
            @thumbnail_images ||= @bike.public_images.select(&:image_url)
          end

          def has_photos?
            bike_image_url.present? && bike_image.present?
          end

          def photos_edit_path
            edit_bike_path(@bike, edit_template: "photos")
          end

          # Thumbnail-sized dotted box (matches a photo thumbnail: 68px, rounded, 2px border)
          def add_photo_box
            link_to(photos_edit_path, class: "tw:flex tw:size-[68px] tw:flex-col tw:items-center tw:justify-center tw:gap-0.5 tw:rounded-sm tw:border-2 tw:border-dashed tw:border-[#d6d4e0] tw:text-[#9a8fc4] tw:no-underline tw:transition tw:hover:border-[#715eb2] tw:hover:text-[#715eb2] tw:dark:border-purple-700 tw:dark:hover:border-purple-300 tw:dark:hover:text-purple-200") do
              safe_join([
                content_tag(:span, "+", class: "tw:text-lg tw:leading-none"),
                content_tag(:span, translation(".add_photo"), class: "tw:text-center tw:text-[10px] tw:leading-tight tw:font-semibold")
              ])
            end
          end
        end
      end
    end
  end
end
