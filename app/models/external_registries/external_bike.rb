module ExternalRegistries
  class ExternalBike
    include ActiveModel::Model
    include ActiveModel::Serialization

    attr_accessor \
      :category,
      :date_stolen,
      :debug,
      :description,
      :image_url,
      :is_stock_img,
      :large_img,
      :location_found,
      :registry_id,
      :registry_name,
      :registry_url,
      :source_unique_id,
      :thumb,
      :thumb_url,
      :type,
      :url

    attr_writer \
      :frame_colors,
      :frame_model,
      :mnfg_name,
      :serial_number,
      :source_name,
      :status

    alias_method :id, :registry_id

    def serial_number
      @serial_number ||= SerialNormalizer.new(serial: @serial_number)
    end

    def stolen
      status&.downcase == "stolen"
    end

    def title_string
      "#{mnfg_name} #{frame_model}"
    end

    def mnfg_name
      @mnfg_name&.titleize
    end

    def frame_model
      @frame_model&.titleize
    end

    def frame_colors
      @frame_colors.to_a.map(&:titleize)
    end

    def source_name
      @source_name&.titleize
    end

    def status
      @status&.titleize
    end
  end
end
