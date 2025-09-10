class EmailNormalizer
  def self.normalize(email = nil)
    return nil unless email.present?

    (email || "").strip.downcase
  end

  def self.obfuscate(email = nil)
    return nil unless email.present?

    email.sub(/\A(..?)(.*)?@(.)(.*)(..)\z/) {
      $1 + "*" * $2.length + "@" + $3 + "*" * $4.length + $5
    }
  end
end
