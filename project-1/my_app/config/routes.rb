Rails.application.routes.draw do
  
  # sidekiq monitoring: https://github.com/mperham/sidekiq/wiki/Monitoring
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'

  get 'login' => 'sessions#new'
  post 'login' => 'sessions#create'
  delete 'logout' => 'sessions#destroy'

  get 'ping' => 'sessions#ping' # for ELB health check

  #resources :images, :only => [:create]

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'
  root 'sessions#new'

  post '/ece1779/servlet/FileUpload' => 'images#create'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products
  resources :users, :except => [:show, :destroy] do 
    resources :images
  end

  namespace :manager do
    get '/' => 'workers#index'
    resources :workers, :only => [:index, :show] do
      delete :terminate_worker
    end
    post   :start_elb # singleton
    put    :start_worker
    post   :purge_images
    post   :reset_alarms

    # AJAX stuff
    get    :worker_status
    get    :elb_status
    get    :image_stats

    # AWS Alarms
    post   :auto_scale
    post   :aws_alarm

    # Login
    get    'login'  => :new
    post   'login'  => :create
    delete 'logout' => :destroy
  end

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
