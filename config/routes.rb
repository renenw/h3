H3::Application.routes.draw do

  get "dashboard/index"
  get "home/index"

  root :to => "home#index"

  resources :sessions
  resources :users

  match '/api/:data_store/sources'                    => 'api#get_sensor_list', :defaults => { :format => 'json' }  # list sources
  match '/api/:data_store/readings'                   => 'api#get_readings', :defaults => { :format => 'json' }     # show the most recent reading / state for each source
  match '/api/:data_store/:source/reading'            => 'api#get_readings', :defaults => { :format => 'json' }     # for a single sensor, show the current state
  match '/api/:data_store/:source/readings'           => 'api#get_history', :defaults => { :format => 'json' }      # show the most recent readings (50) for a sensor
  match '/api/:data_store/:source/:dimension'         => 'api#get_summaries', :defaults => { :format => 'json' }    # retrieve the last 50 summarised data points for a sensor, for a dimension
  match '/api/:data_store/:source/:dimension/summary' => 'api#get_summary', :defaults => { :format => 'json' }      # get the most recent summary value for a sensor, for a dimension
  match '/api/:data_store/:dimension'                 => 'api#get_summaries', :defaults => { :format => 'json' }    # for a dimension, retrieve all the summarised values for all sensors

  match 'login'   => 'sessions#new' 


  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
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

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
