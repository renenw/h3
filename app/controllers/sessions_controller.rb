class SessionsController < ApplicationController

  skip_before_filter :ensure_logged_in, only: [:new, :create]

  def new
  end

  def create
    user = User.find_by_email(params[:email])
    if user && user.authenticate(params[:password])
      session[:user_id]    = user.id
      session[:data_store] = user.data_store
      redirect_to root_url, :notice => "Logged in!"
    else
      flash.now.alert = "Invalid email or password"
      render "new"
    end
  end

  def destroy
    session[:user_id]    = nil
    session[:data_store] = nil
    redirect_to root_url, :notice => "Logged out!"
  end
end


