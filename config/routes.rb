Rails.application.routes.draw do
  devise_for :users,
             path: "auth",
             path_names: {
               sign_in: "login",
               sign_out: "logout"
             },
             skip: [ :registrations, :passwords ],
             controllers: {
               sessions: "users/sessions"
             }

  devise_scope :user do
    post "auth/register",
         to: "users/registrations#create",
         as: :user_registration

    post "auth/refresh",
         to: "users/refresh_tokens#create"
  end

  get "up" => "rails/health#show",
      as: :rails_health_check

  get "auth/me", to: "users/me#show"

  resources :expenses, only: %i[index show create update destroy]
end
