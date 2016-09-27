class EmailNormalizer
  def self.normalize(email = nil)
    (email || '').strip.downcase
  end
end