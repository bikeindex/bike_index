class EmailNormalizer
  def self.normalize(email = nil)
    return nil unless email.present?
    (email || "").strip.downcase
  end
end
