class FileCacheMaintainer
  class << self
    def assign_blocklist_ids(ids)
      if ids.present?
        redis.sadd blocklist_id, ids.map { |i| normalized(i) }.reject { |i| i.blank? }
      end
    end

    def blocklist
      return [] unless redis.type(info_id) == "set"
      redis.smembers blocklist_id
    end

    def reset_blocklist_ids(ids)
      redis.expire(blocklist_id, 0)
      assign_blocklist_ids(ids)
    end

    def blocklist_include?(id)
      redis.sismember blocklist_id, normalized(id)
    end

    def descriptions
      {
        "manufacturers.tsv" => "Manufacturers list",
        "current_stolen_bikes.tsv" => "Stolen",
        "approved_current_stolen_bikes.tsv" => "Stolen (without blocklisted bikes)",
        "current_stolen_with_reports.tsv" => "Stolen with serials & police reports",
        "approved_current_stolen_with_reports.tsv" => "Stolen with serials & police reports (without blocklisted bikes)",
        "all_stolen_cache.json" => "Cached API response of all stolen bikes"
      }
    end

    def update_file_info(filename, updated_at = nil)
      updated_at ||= Time.current
      begin
        redis.hset info_id, filename, updated_at.to_i
      rescue
        # Sometimes key errors from wrong type, so reset it!
        reset_file_info(filename, updated_at.to_i)
      end
      files
    end

    def reset_file_info(filename, updated_at = nil)
      redis.expire(info_id, 0)
      update_file_info(filename, updated_at)
    end

    def file_info_hash(k)
      path = Pathname.new(k)
      daily_export = path.basename.to_s.match(/\A\d+/).present?
      {
        path: k,
        filename: path.basename.to_s,
        daily: daily_export,
        updated_at: @result[k],
        description: descriptions[path.basename.to_s]
      }
    end

    def files
      return [] unless redis.type(info_id) == "hash"
      @result = redis.hgetall(info_id)
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
      Redis.current
    end

    def uploader_from_filename(filename)
      /\.json/.match?(filename) ? JsonUploader.new : TsvUploader.new
    end

    def remove_file(file_info_hash)
      uploader = uploader_from_filename(file_info_hash["filename"])
      uploader.retrieve_from_store!(file_info_hash["filename"])
      uploader.remove!
      redis.hdel(info_id, file_info_hash["path"])
    end
  end
end
