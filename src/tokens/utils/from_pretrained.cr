require "http/client"
require "file_utils"

module Tokens
  struct FromPretrainedParameters
    property revision : String
    property token : String?

    def initialize(@revision = "main", @token = nil)
    end
  end

  def self.from_pretrained(identifier : String, params : FromPretrainedParameters? = nil) : String
    valid_chars = Set{'-', '_', '.', '/'}
    identifier.each_char do |c|
      unless c.ascii_alphanumeric? || valid_chars.includes?(c)
        raise "Model \"#{identifier}\" contains invalid characters, expected only alphanumeric or '-', '_', '.', '/'"
      end
    end

    p = params || FromPretrainedParameters.new

    p.revision.each_char do |c|
      unless c.ascii_alphanumeric? || valid_chars.includes?(c)
        raise "Revision \"#{p.revision}\" contains invalid characters, expected only alphanumeric or '-', '_', '.', '/'"
      end
    end

    cache_dir = File.join(Dir.current, "data", "from_pretrained", identifier)
    Dir.mkdir_p(cache_dir)
    cache_path = File.join(cache_dir, "tokenizer.json")

    return cache_path if File.exists?(cache_path)

    url = "https://huggingface.co/#{identifier}/resolve/#{p.revision}/tokenizer.json"

    headers = HTTP::Headers.new
    headers["User-Agent"] = "tokens-crystal/0.1.0"
    if token = p.token
      headers["Authorization"] = "Bearer #{token}"
    end

    HTTP::Client.get(url, headers: headers) do |response|
      raise "HTTP #{response.status_code}: #{response.status_message}" unless response.success?
      File.write(cache_path, response.body_io.gets_to_end)
    end

    cache_path
  end
end
