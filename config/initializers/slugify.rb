class Slugifyer
  def self.slugify(string)
    string.gsub(/\s/, '-').gsub(/([^A-Za-z0-9_\-]+)/,'').downcase
  end
end