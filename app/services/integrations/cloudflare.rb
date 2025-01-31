class Integrations::Cloudflare
  API_TOKEN = ENV["CLOUDFLARE_TOKEN"]
  ZONE = "82c727a79571ff204a7ddc188d1806ec"

  require "net/http"

  def connection
    @connection ||= Faraday.new(url: "https://api.cloudflare.com") do |conn|
      conn.headers["Content-Type"] = "application/json"
      conn.headers["Authorization"] = "Bearer #{API_TOKEN}"
      conn.adapter Faraday.default_adapter
    end
  end

  def expire_cache(url_or_url_array)
    urls = Array(url_or_url_array)
    result = connection.post("/client/v4/zones/#{ZONE}/purge_cache") do |req|
      req.body = {files: urls}.to_json
    end
    JSON.parse(result.body)
  end
end
