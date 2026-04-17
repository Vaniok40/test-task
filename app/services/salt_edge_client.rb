class SaltEdgeClient
  def initialize
    @certificate = File.read(Rails.root.join(ENV.fetch("SALT_EDGE_CERT_PATH")))
    @private_key = OpenSSL::PKey::RSA.new(File.read(Rails.root.join(ENV.fetch("SALT_EDGE_KEY_PATH"))))
    @cert_base64 = Base64.strict_encode64(OpenSSL::X509::Certificate.new(@certificate).to_der)
  end

  def post(path, body)
    request(:post, path, body)
  end

  def get(path)
    request(:get, path, nil)
  end

  private

  def base_url
    ENV.fetch("SALT_EDGE_BASE_URL")
  end

  def provider_code
    ENV.fetch("SALT_EDGE_PROVIDER_CODE")
  end

  def key_id
    ENV.fetch("SALT_EDGE_KEY_ID")
  end

  def redirect_uri
    ENV.fetch("TPP_REDIRECT_URI")
  end

  def request(method, path, body)
    url        = "#{base_url}/#{provider_code}/api/berlingroup/v1#{path}"
    request_id = SecureRandom.uuid
    date       = Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT")
    body_json  = body ? body.to_json : nil
    headers    = build_headers(path, request_id, date, body_json)

    conn = Faraday.new do |f|
      f.adapter Faraday.default_adapter
    end

    if method == :post
      conn.post(url, body_json, headers)
    else
      conn.get(url, nil, headers)
    end
  end

  def build_headers(path, request_id, date, body_json)
    headers         = {}
    headers_to_sign = []

    if body_json
      digest               = "SHA-256=" + Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(body_json))
      headers["Digest"]    = digest
      headers_to_sign     << "digest"
    end

    headers["Date"]         = date
    headers["X-Request-ID"] = request_id
    headers_to_sign        += [ "date", "x-request-id" ]

    if path == "/consents"
      headers["TPP-Redirect-URI"]       = redirect_uri
      headers["TPP-Redirect-Preferred"] = "true"
      headers_to_sign                  << "tpp-redirect-uri"
    end

    headers["Content-Type"]              = "application/json"
    headers["PSU-IP-Address"]            = "127.0.0.1"
    headers["TPP-Signature-Certificate"] = @cert_base64
    headers["Signature"]                 = build_signature(headers, headers_to_sign)

    headers
  end

  def build_signature(headers, headers_to_sign)
    signing_string = headers_to_sign.map { |h| "#{h}: #{headers[canonical(h)]}" }.join("\n")
    signature      = Base64.strict_encode64(@private_key.sign(OpenSSL::Digest::SHA256.new, signing_string))

    %(Signature keyId="#{key_id}",algorithm="rsa-sha256",headers="#{headers_to_sign.join(" ")}",signature="#{signature}")
  end

  def canonical(header_name)
    header_name.split("-").map(&:capitalize).join("-")
  end
end
