# frozen_string_literal: true

ErrorRadar::Engine.routes.draw do
  root to: 'dashboard#index'

  get    'errors',            to: 'errors#index',         as: :errors
  post   'errors/bulk',       to: 'errors#bulk',          as: :errors_bulk
  get    'errors/:id',        to: 'errors#show',          as: :error
  patch  'errors/:id/status', to: 'errors#update_status', as: :error_status
  delete 'errors/:id',        to: 'errors#destroy'
end
