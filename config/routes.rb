Rails.application.routes.draw do
  devise_for :accounts, ActiveAdmin::Devise.config
  # TODO: fix later
  # mount API::Root => '/api'
  mount API::V1::Root => '/'
end
