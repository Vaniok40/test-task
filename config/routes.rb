Rails.application.routes.draw do
  root "ais#index"

  get "/consents/new", to: "ais#new_consent", as: :new_consent
  post "/consents", to: "ais#create_consent", as: :consents
  get "/callback", to: "ais#callback", as: :callback
  get "/accounts", to: "ais#accounts", as: :accounts
  get "/transactions", to: "ais#transactions", as: :transactions
end
