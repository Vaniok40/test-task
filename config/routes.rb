Rails.application.routes.draw do
  root "ais#index"

  get  "/consents/new",  to: "ais#new_consent"
  post "/consents",      to: "ais#create_consent"
  get  "/callback",      to: "ais#callback"
  get  "/accounts",      to: "ais#accounts"
  get  "/transactions",  to: "ais#transactions"
end
