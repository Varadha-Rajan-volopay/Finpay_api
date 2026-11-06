require "sidekiq/web"

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  mount Sidekiq::Web => "/sidekiq"

  devise_for :users,
             path: "api/v1/auth",
             path_names: {
               sign_in: "login",
               sign_out: "logout"
             },
             skip: [:registrations, :passwords],
             controllers: {
               sessions: "api/v1/users/sessions"
             }

  devise_scope :user do
    post "api/v1/auth/register",
         to: "api/v1/users/registrations#create",
         as: :user_registration

    post "api/v1/auth/refresh",
         to: "api/v1/users/refresh_tokens#create"
  end

  namespace :api do
    namespace :v1 do
      get "auth/me", to: "users/me#show"

      resources :expenses, only: %i[index show create update destroy] do
        member do
          post :approve
          post :reject
          post :reimburse
          post :archive
        end
      end
    end
  end

  get "up" => "rails/health#show",
      as: :rails_health_check
end
