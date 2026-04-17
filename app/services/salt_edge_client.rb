class SaltEdgeClient
  def initialize
    @private_key = OpenSSL::PKey::RSA.new(File.read(Rails.root.join(ENV.fetch("SALT_EDGE_KEY_PATH"))))
    @cert_base64 = Base64.strict_encode64(
      OpenSSL::X509::Certificate.new(File.read(Rails.root.join(ENV.fetch("SALT_EDGE_CERT_PATH")))).to_der
    )
  end

  def post(path, body)
    JSON.parse(request(:post, path, body).body)
  end

  def get(path, consent_id: nil)
    JSON.parse(request(:get, path, nil, consent_id).body)
  end

  private

  def base_url = ENV.fetch("SALT_EDGE_BASE_URL")
  def provider_code = ENV.fetch("SALT_EDGE_PROVIDER_CODE")
  def key_id = ENV.fetch("SALT_EDGE_KEY_ID")
  def redirect_uri = ENV.fetch("TPP_REDIRECT_URI")

  def request(method, path, body, consent_id = nil)
    url = "#{base_url}/#{provider_code}/api/berlingroup/v1#{path}"
    body_json = body&.to_json
    headers = build_headers(path, body_json, consent_id)

    conn = Faraday.new { |f| f.adapter Faraday.default_adapter }
    method == :post ? conn.post(url, body_json, headers) : conn.get(url, nil, headers)
  end

  def build_headers(path, body_json, consent_id)
    headers = {}
    headers_to_sign = []

    headers["Digest"] = "SHA-256=" + Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(body_json || ""))
    headers["Date"] = Time.now.utc.strftime("%a, %d %b %Y %H:%M:%S GMT")
    headers["X-Request-ID"] = SecureRandom.uuid
    headers_to_sign += ["digest", "date", "x-request-id"]

    if path == "/consents"
      headers["TPP-Redirect-URI"] = redirect_uri
      headers["TPP-Redirect-Preferred"] = "true"
      headers_to_sign << "tpp-redirect-uri"
    end

    headers["Consent-Id"] = consent_id if consent_id
    headers["Content-Type"] = "application/json"
    headers["PSU-IP-Address"] = "127.0.0.1"
    headers["TPP-Signature-Certificate"] = @cert_base64
    headers["Signature"] = build_signature(headers, headers_to_sign)

    headers
  end

  def build_signature(headers, headers_to_sign)
    signing_string = headers_to_sign.map { |h| "#{h}: #{headers[canonical(h)]}" }.join("\n")
    signature = Base64.strict_encode64(@private_key.sign(OpenSSL::Digest::SHA256.new, signing_string))
    %(Signature keyId="#{key_id}",algorithm="rsa-sha256",headers="#{headers_to_sign.join(" ")}",signature="#{signature}")
  end

  def canonical(header_name)
    {
      "digest" => "Digest",
      "date" => "Date",
      "x-request-id" => "X-Request-ID",
      "tpp-redirect-uri" => "TPP-Redirect-URI",
      "tpp-redirect-preferred" => "TPP-Redirect-Preferred"
    }.fetch(header_name)
  end
end
