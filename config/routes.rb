Rails.application.routes.draw do
  # devise_for :accounts, ActiveAdmin::Devise.config
  devise_for :accounts
  mount API::Root => '/api'
end
