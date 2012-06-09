class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :add_data_store_to_params

  private

    def add_data_store_to_params
      params['data_store'] = session[:data_store] unless params['data_store']
    end

    def current_user
      @current_user ||= User.find(session[:user_id]) if session[:user_id]
    end

    def sources
      @sources ||= memcache.get_sources
    end

    def session_logged_in?
      !session[:user_id].nil?
    end

    def memcache
      MemcacheWrapper.instance
    end

    helper_method :current_user
    helper_method :session_logged_in?
    helper_method :session_data_store
    helper_method :memcache
    helper_method :sources

end
