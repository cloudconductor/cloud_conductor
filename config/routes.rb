Rails.application.routes.draw do
  devise_for :accounts, ActiveAdmin::Devise.config
  mount API::Root => '/api'
end
