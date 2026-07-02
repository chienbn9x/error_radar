# frozen_string_literal: true

ErrorRadar::Engine.routes.draw do
  root to: 'dashboard#index'

  # REST API — JSON endpoints for CI/CD, external dashboards, scripts
  namespace :api, defaults: { format: :json } do
    resources :errors, only: %i[index show update]
    resource  :stats,  only: [:show]
  end

  # Web UI
  get    'errors',                           to: 'errors#index',               as: :errors
  post   'errors/bulk',                      to: 'errors#bulk',                as: :errors_bulk
  post   'errors/:id/github_issue',          to: 'errors#create_github_issue', as: :error_github_issue
  get    'errors/:id',                       to: 'errors#show',                as: :error
  patch  'errors/:id/status',                to: 'errors#update_status',       as: :error_status
  patch  'errors/:id/assign',                to: 'errors#assign',              as: :error_assign
  post   'errors/:id/comments',              to: 'errors#comment',             as: :error_comments
  delete 'errors/:id/comments/:cid',         to: 'errors#destroy_comment',     as: :error_comment
  delete 'errors/:id',                       to: 'errors#destroy'

  post 'maintenance/purge', to: 'dashboard#purge', as: :maintenance_purge
end
