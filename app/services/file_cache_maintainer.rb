class FileCacheMaintainer
  class << self
    def assign_blocklist_ids(ids)
      normalized_ids = ids&.map { |i| normalized(i) }&.reject(&:blank?)
      if normalized_ids.present?
        RedisPool.conn { |r| r.sadd(blocklist_id, normalized_ids) }
      end
    end

    def blocklist
      return [] unless redis.type(info_id) == "set"

      RedisPool.conn { |r| r.smembers blocklist_id }
    end

    def reset_blocklist_ids(ids)
      RedisPool.conn { |r| r.expire(blocklist_id, 0) }
      assign_blocklist_ids(ids)
    end

    def blocklist_include?(id)
      RedisPool.conn { |r| r.sismember blocklist_id, normalized(id) }
    end

    def descriptions
      {
        "manufacturers.tsv" => "Manufacturers list",
        "current_stolen_bikes.tsv" => "Stolen",
        "approved_current_stolen_bikes.tsv" => "Stolen (without blocklisted bikes)",
        "current_stolen_with_reports.tsv" => "Stolen with serials & police reports",
        "approved_current_stolen_with_reports.tsv" => "Stolen with serials & police reports (without blocklisted bikes)",
        "all_stolen_cache.json" => "Cached API response of all stolen bikes",
        "stolen.geojson" => "GeoJSON data on all the stolen bikes"
      }
    end

    def update_file_info(filename, updated_at = nil, retrying = false)
      updated_at ||= Time.current
      begin
        RedisPool.conn { |r| r.hset info_id, filename, updated_at.to_i }
      rescue => e
        # Make sure it doesn't loop infinitely
        raise e if retrying

        # Sometimes key errors from wrong type, so reset it!
        reset_file_info(filename, updated_at.to_i)
      end
      files
    end

    def reset_file_info(filename, updated_at = nil)
      RedisPool.conn { |r| r.expire(info_id, 0) }
      update_file_info(filename, updated_at, true)
    end

    def file_info_hash(k)
      path = Pathname.new(k)
      file_base = path.basename.to_s
      daily_export = file_base.match(/\A\d+/).present? || file_base == "stolen.geojson"
      {
        path: k,
        filename: file_base,
        daily: daily_export,
        updated_at: @result[k],
        description: descriptions[file_base]
      }
    end

    def files
      return [] unless RedisPool.conn { |r| r.type(info_id) } == "hash"

      @result = RedisPool.conn { |r| r.hgetall(info_id) }
      @result.keys.map { |k| file_info_hash(k).with_indifferent_access }
        .sort_by { |t| t[:filename] }.sort_by { |t| t[:daily] ? 1 : 0 }
    end

    def cached_all_stolen
      files.select { |t| t["filename"] =~ /all_stolen_cache\.json/ }
        .max_by { |a| a["filename"] }
    end

    def normalized(id)
      id.to_s[/\d+/]
    end

    def info_id
      "#{base_id}_info"
    end

    def blocklist_id
      "#{base_id}_info"
    end

    def base_id
      "#{Rails.env[0..2]}_tsv"
    end

    def redis
      @redis ||= Redis.new # TODO: Switch to connection pool, preferred way of accessing redis
    end

    def uploader_from_filename(filename)
      /\.json/.match?(filename) ? JsonUploader.new : TsvUploader.new
    end

    def remove_file(file_info_hash)
      uploader = uploader_from_filename(file_info_hash["filename"])
      uploader.retrieve_from_store!(file_info_hash["filename"])
      uploader.remove!
      RedisPool.conn { |r| r.hdel(info_id, file_info_hash["path"]) }
    end
  end
end
