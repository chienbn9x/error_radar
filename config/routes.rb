# frozen_string_literal: true

ErrorRadar::Engine.routes.draw do
  root to: 'dashboard#index'
  get   'errors/:id',        to: 'dashboard#show',          as: :error
  patch 'errors/:id/status', to: 'dashboard#update_status', as: :error_status
end
