class TsvMaintainer

  class << self
    def set_blacklist_ids(ids)
      if ids.present?
        redis.sadd blacklist_id, ids.map{ |i| normalized(i) }.reject{ |i| i.blank? }
      end
    end

    def blacklist
      return [] unless redis.type(info_id) == 'set'
      redis.smembers blacklist_id
    end

    def reset_blacklist_ids(ids)
      redis.expire(blacklist_id, 0)
      set_blacklist_ids(ids)
    end

    def blacklist_include?(id)
      redis.sismember blacklist_id, normalized(id)
    end

    def descriptions
      {
        'current_stolen_bikes.tsv' => 'Stolen',
        'approved_current_stolen_bikes.tsv' => 'Stolen (without blacklisted bikes)',
        'current_stolen_with_reports.tsv' => 'Stolen with serials & police reports',
        'approved_current_stolen_with_reports.tsv' => 'Stolen with serials & police reports (without blacklisted bikes)',
      }
    end

    def update_tsv_info(filename, updated_at=nil)
      updated_at ||= Time.now
      begin
        redis.hset info_id, filename, updated_at.to_i
      rescue => e
        puts e # Sometimes key errors if wrong type, but we need to use hset or we don't create it
      end
      tsvs
    end

    def reset_tsv_info(filename, updated_at=nil)
      redis.expire(info_id, 0)
      update_tsv_info(filename, updated_at)
    end

    def tsv_info_hash(k)
      path = Pathname.new(k)
      {
        path: k,
        filename: path.basename.to_s,
        updated_at: @result[k],
        description: descriptions[path.basename.to_s]
      }
    end

    def tsvs
      return [] unless redis.type(info_id) == 'hash'
      @result = redis.hgetall(info_id)
      @result.keys.map{ |k| tsv_info_hash(k).with_indifferent_access }
    end

    def normalized(id)
      id.to_s[/\d+/]
    end

    def info_id
      "#{base_id}_info"
    end  

    def blacklist_id
      "#{base_id}_info"
    end

    def base_id
      "#{Rails.env[0..2]}_tsv"
    end

    def redis
      Redis.current
    end
  end

end