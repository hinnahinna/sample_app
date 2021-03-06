# frozen_string_literal: true

Rails.application.routes.draw do
  # get 'users/new'
  root 'static_pages#home'
  # get 'static_pages/home'
  # get 'static_pages/help'
  # get 'static_pages/about'
  # get 'static_pages/contact'
  get    '/help',    to: 'static_pages#help'
  get    '/about',   to: 'static_pages#about'
  get    '/contact', to: 'static_pages#contact'
  get    '/signup',  to: 'users#new'
  post   '/signup',  to: 'users#create'
  get    '/login',   to: 'sessions#new'
  post   '/login',   to: 'sessions#create'
  delete 'logout',   to: 'sessions#destroy'
  resources :users do
    # use include user id URL
    member do
      get :following, :followers
    end
  end
  # /users/1などを有効にする
  resources :account_activations, only: [:edit]
  resources :password_resets,     only: %i[new create edit update]
  resources :microposts,          only: %i[create destroy]
  resources :relationships,       only: %i[create destroy]

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
