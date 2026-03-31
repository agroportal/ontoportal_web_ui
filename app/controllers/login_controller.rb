class LoginController < ApplicationController

  layout :determine_layout

  def index
    # Sets the redirect properties
    if params[:redirect]
      # Get the original, encoded redirect
      uri = URI.parse(request.url)
      orig_params = Hash[uri.query.split("&").map {|e| e.split("=",2)}].symbolize_keys
      @redirect_url = orig_params[:redirect]
    else
      referer = request.referer
      path = URI(referer).path rescue "/" if referer
      @redirect_url = referer
    end
    session[:redirect] = @redirect_url
  end

  # logs in a user
  def create
    @errors = validate(params[:user])

    username = if is_email(params[:user][:username])
                LinkedData::Client::Models::User.find_by_email(params[:user][:username]).first&.username
              else
                params[:user][:username]
              end

    @errors << t("login.invalid_account_combination") if username.nil?

    if @errors.any?
      @redirect_url = params[:redirect]
      return render :action => 'index'
    end

    logged_in_user = LinkedData::Client::Models::User.authenticate(username, params[:user][:password])
    if logged_in_user && !logged_in_user.errors
      login(logged_in_user)
      raw_redirect = params[:redirect] || session[:redirect]
      redirect = raw_redirect ? CGI.unescape(raw_redirect) : "/"
      redirect = append_apikey_if_rest_url(redirect, logged_in_user)
      redirect_to redirect, allow_other_host: true
    else
      @errors << t('login.invalid_account_combination')
      @redirect_url = params[:redirect] || session[:redirect]
      render :action => 'index'
    end
  end

  def create_omniauth
    auth_data = request.env['omniauth.auth']
    auth_code = auth_data.credentials.token
    token_provider = helpers.omniauth_token_provider(params[:provider])

    logged_in_user = LinkedData::Client::HTTP.post("#{LinkedData::Client.settings.rest_url}/users/authenticate", { access_token: auth_code , token_provider: token_provider})
    if logged_in_user && !logged_in_user.errors
      login(logged_in_user)
      redirect = "/"

      if session[:redirect]
        redirect = CGI.unescape(session[:redirect])
      end

      redirect = append_apikey_if_rest_url(redirect, logged_in_user)
      redirect_to redirect, allow_other_host: true
    else
      @errors =  [t('login.authentication_failed', provider: params[:provider])]
      render :action => 'index'
    end
  end

  # Login as the provided username (only for admin users)
  def login_as
    unless session[:user] && session[:user].admin?
      redirect_to "/"
      return
    end

    user = params[:login_as]
    new_user = LinkedData::Client::Models::User.find_by_username(user).first

    if new_user
      session[:admin_user] = session[:user]
      session[:user] = new_user
      session[:user].apikey = session[:admin_user].apikey
    end

    #redirect_to request.referer rescue redirect_to "/"
    redirect_to "/"
  end

  # logs out a user
  def destroy
    if session[:admin_user]
      old_user = session[:user]
      session[:user] = session[:admin_user]
      session.delete(:admin_user)
      flash[:success] = t('login.admin_logged_out', old_user: old_user.username, user: session[:user].username).html_safe
    else
      session[:user] = nil
      flash[:success] = t('login.user_logged_out')
    end
    redirect_to request.referer || "/"
  end

  def lost_password
  end

  def lost_password_success
  end


  # Sends a new password to the user
  def send_pass
    username = params[:user][:account_name]
    email = params[:user][:email]
    resp = LinkedData::Client::HTTP.post("/users/create_reset_password_token", {username: username, email: email})

    if resp.nil?
      redirect_to "/lost_pass_success"
    else
      flash[:notice] = resp.errors.first + t('login.try_again_notice')
      redirect_to "/lost_pass"
    end
  end

  def reset_password
    username = params[:un]
    email = params[:em]
    token = params[:tk]
    @user = LinkedData::Client::HTTP.post("/users/reset_password", {username: username, email: email, token: token})
    if @user.is_a?(LinkedData::Client::Models::User)
      login(@user)
      @user = LinkedData::Client::Models::User.find(@user.id, include: 'all')
      @user.validate_password = true
      render "users/edit"
    else
      flash[:notice] = @user.errors.first + t('login.reset_password_again')
      redirect_to "/lost_pass"
    end
  end

  private

  def append_apikey_if_rest_url(redirect_url, user)
    return redirect_url if redirect_url.blank?

    rest_url = LinkedData::Client.settings.rest_url
    fairness_url = $FAIRNESS_URL
    # Basic check to see if the URL is a REST API URL or Fairness URL
    if redirect_url.include?(rest_url) || (fairness_url.present? && redirect_url.include?(fairness_url))
      uri = URI.parse(redirect_url) rescue nil
      return redirect_url unless uri
      
      params = URI.decode_www_form(uri.query || "")
      # Remove existing apikey if any, then add the user's apikey
      params.reject! { |k, v| k == "apikey" }
      params << ["apikey", user.apikey]
      uri.query = URI.encode_www_form(params)
      redirect_url = uri.to_s
    end
    redirect_url
  rescue
    redirect_url
  end

  def login(user)
    return unless user
    session[:user] = user
    custom_ontologies_text = session[:user].customOntology && !session[:user].customOntology.empty? ? t('login.custom_ontology_set') : ""
    notice = t('login.welcome') + user.username.to_s + "</b>! " + custom_ontologies_text
    flash[:success] = notice.html_safe
  end

  def validate(params)
    errors=[]

    if params[:username].nil? || params[:username].length <1
      errors << t('login.error_account_name')
    end
    if params[:password].nil? || params[:password].length <1
      errors << t('login.error_password')
    end

    return errors
  end

  def is_email(email)
    email =~ /\A[^@\s]+@[^@\s]+\z/
  end


end
