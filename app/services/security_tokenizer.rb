module SecurityTokenizer
  extend Functionable

  EARLIEST_TOKEN_TIME = 1427848192 # 2015-03-31T17:29:52

  def new_token(time = nil)
    t = (time.blank? ? Time.current : time).to_i
    "#{t}-" + SecureRandom.hex + Digest::MD5.hexdigest("#{SecureRandom.hex}-#{t}")
  end

  # Passwords have to be less than 72 characters. Lazy hack
  def new_password_token(time = nil)
    new_token(time).slice(0, 60)
  end

  # Because of texting length concerns, use an abbreviated token
  def new_short_token
    new_token.split("-")[1].slice(2, 21)
  end

  def token_time(str)
    recognized_token?(str) ? Time.at(str.to_s.split("-").first.to_i) : Time.at(EARLIEST_TOKEN_TIME)
  end

  # token_time floors what it can't read at EARLIEST_TOKEN_TIME, which reads as long expired
  def recognized_token?(str)
    time, hex = str.to_s.split("-")
    time.present? && hex.present? && time.to_i > EARLIEST_TOKEN_TIME
  end
end
