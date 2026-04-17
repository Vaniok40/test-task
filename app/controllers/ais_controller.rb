class AisController < ApplicationController
  def index
  end

  def new_consent
  end

  def create_consent
    data = client.post("/consents", consent_params)

    if data["consentId"]
      consent = Consent.create!(
        consent_id: data["consentId"],
        status: data["consentStatus"],
        valid_until: 90.days.from_now.to_date
      )
      session[:consent_id] = consent.id

      sca_redirect = client.get("/consents/#{consent.consent_id}").dig("_links", "scaRedirect", "href")
      redirect_to sca_redirect, allow_other_host: true
    else
      render :new_consent, status: :unprocessable_entity
    end
  end

  def callback
    @consent = current_consent
  end

  def accounts
    @accounts = fetch("accounts")
  end

  def transactions
    @transactions = fetch("accounts/#{params[:account_id]}/transactions?bookingStatus=both")
  end

  private

  def client
    @client ||= SaltEdgeClient.new
  end

  def current_consent
    Consent.find_by(id: session[:consent_id])
  end

  def fetch(path)
    return redirect_to new_consent_path unless current_consent

    data = client.get("/#{path}", consent_id: current_consent.consent_id)
    key = path.split("/").last.split("?").first
    result = data[key] || []
    result.is_a?(Hash) ? result.values.flatten : result
  end

  def consent_params
    {
      access: { allPsd2: "allAccounts" },
      recurringIndicator: true,
      validUntil: 90.days.from_now.to_date.to_s,
      frequencyPerDay: 4,
      combinedServiceIndicator: false
    }
  end
end
