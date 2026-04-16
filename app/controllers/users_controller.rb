class UsersController < ApplicationController

  before_action :verify_owner, only: [:edit, :subscribe, :un_subscribe]
  before_action :authorize_admin, only: [:index,:subscribe, :un_subscribe]
  layout :determine_layout

  include TurboHelper


  def index

    onts = LinkedData::Client::Models::Ontology.all(include: 'administeredBy')
    projects = LinkedData::Client::Models::Project.all(include: 'creator')

    @users =  LinkedData::Client::Models::User.all(include: 'all')
    @users.each do |user|
      user.ontologies = onts.select {|o| o.administeredBy.include? user.id }
      user.project = projects.select {|p| p.creator.include? user.id }
    end

  end

  # GET /users/1
  # GET /users/1.xml
  def show
    @title = t('home.account_title')
    if session[:user].nil?
      redirect_to controller: 'login', action: 'index', redirect: '/account'
      return
    end
    @user = if session[:user].admin? && params.has_key?(:id)
              find_user(params[:id])
            else
              find_user(session[:user].id)
            end
    @ontologies = LinkedData::Client::Models::Ontology.all(ignore_custom_ontologies: true);
    @all_ontologies_for_select = @ontologies.map {|x| ["#{x.name} (#{x.acronym})", x.acronym]}

    @user_ontologies = @user.customOntology
    @user_ontologies ||= []

    @admin_ontologies = @ontologies.select {|o| o.administeredBy.include? @user.id }
    @accessed_ontologies = @ontologies.select {|o| o.acl.include? @user.id }

    projects = LinkedData::Client::Models::Project.all;
    @user_projects = projects.select {|p| p.creator.include? @user.id }

    @user_subscriptions = LinkedData::Client::HTTP.get("/users/#{@user.username}/subscriptions", { apikey: get_apikey }) || []
  end

  # GET /users/new
  def new
    @user = LinkedData::Client::Models::User.new
  end

  # GET /users/1;edit
  def edit
    @user = find_user

    if params[:password].eql?("true")
      @user.validate_password = true
    end
  end

  # POST /users
  # POST /users.xml
  def create
    @errors = validate(user_params)
    @user = LinkedData::Client::Models::User.new(values: user_params)

    if @errors.size < 1
      @user_saved = @user.save
      if response_error?(@user_saved)
        @errors = response_errors(@user_saved)
        # @errors = {acronym: "Username already exists, please use another"} if @user_saved.status == 409
        render action: "new"
      else
        # Attempt to register user to list
        if params[:user][:register_mail_list]
          SubscribeMailer.register_for_announce_list(@user.email,@user.firstName,@user.lastName).deliver rescue nil
        end

        flash[:notice] = t('users.account_successfully_created')
        session[:user] = LinkedData::Client::Models::User.authenticate(@user.username, @user.password)
        redirect_to_user_ontologies
      end
    else
      render action: "new"
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update
    @user = find_user
    @errors = validate_update(user_params)
    if @errors.size < 1

      if params[:user][:password]
        error_response = @user.update(values: { password: params[:user][:password] })
      else
        user_roles = @user.role

        if @user.admin? != (params[:user][:admin].to_i == 1)
          user_roles = update_role(@user)
        end

        @user.update_from_params(user_params.merge!(role: user_roles))
        error_response = @user.update
      end

      if response_error?(error_response)
        @errors = response_errors(error_response)
        # @errors = {acronym: "Username already exists, please use another"} if error_response.status == 409
        render action: "edit"
      else
        flash[:notice] = t('users.account_successfully_updated')

        if session[:user].username == @user.username
          session[:user].update_from_params(user_params)
        end
        redirect_to user_path(@user.username)
      end
    else
      render action: "edit"
    end
  end

  # DELETE /users/1
  def destroy
    response = {errors: nil, success: ''}
    @user = find_user

    if session[:user].admin?
      @user.delete
      response[:success] << t('users.user_deleted_successfully')

    else
      response[:errors] << t('users.not_permitted')
    end

    respond_to do |format|
      format.turbo_stream do
        if response[:errors]
          render_turbo_stream alert(type: 'danger') { response[:errors].to_s }
        else
          render turbo_stream: [
            alert(type: 'success') { response[:success] },
            turbo_stream.remove(params[:id])
          ]
        end
      end
    end
  end

  def custom_ontologies
    @user = find_user
    custom_ontologies = params[:ontologies] || []

    @user.update_from_params(customOntology: custom_ontologies)
    error_response = !@user.update
    if error_response
      flash[:notice] = t('users.error_saving_custom_ontologies')
    else
      session[:user].update_from_params(customOntology: @user.customOntology)
      flash[:notice] = if @user.customOntology.empty?
                        t('users.custom_ontologies_cleared')
                       else
                        t('users.custom_ontologies_saved')
                       end
    end
    redirect_to user_path(@user.username)
  end


  def subscribe
    @user = find_user
    deliver "subscribe", SubscribeMailer.register_for_announce_list(@user.email,@user.firstName,@user.lastName)
  end


  def un_subscribe
    @email = params[:email]
    deliver "unsubscribe", SubscribeMailer.unregister_for_announce_list(@email)
  end


  private

  def find_user(id = params[:id])
    id = helpers.unescape(id)
    @user = LinkedData::Client::Models::User.find(id.split('/').last, {include: 'all'})

    not_found("User with id #{id} not found") if @user.nil?

    @user
  end

  def deliver(action,job)
    begin
      job.deliver
      to_or_from = action.eql?("subscribe") ? "to" : "from"
      flash[:success] = t('users.subscribe_flash_message', action: action, to_or_from: to_or_from, list: $ANNOUNCE_LIST)
    rescue => exception
      flash[:error] = t('users.error_subscribe')
    end
    redirect_to '/account'
  end

  def user_params
    params[:user]["orcidId"] = extract_id_from_url(params[:user]["orcidId"], 'orcid.org')
    params[:user]["githubId"] = extract_id_from_url(params[:user]["githubId"], 'github.com')
    p = params.require(:user).permit(:firstName, :lastName, :username, :orcidId, :githubId, :email, :email_confirmation, :password,
                                     :password_confirmation, :register_mail_list, :admin, :terms_and_conditions, :subscribed_to_ontologies, :subscribed_to_projects)
    p.to_h
  end

  def extract_id_from_url(url, pattern)
    if url && url.include?(pattern)
      url.split('/').last
    else
      url
    end
  end

  def unescape_id
    params[:id] = CGI.unescape(params[:id])
  end

  def verify_owner
    return if current_user_admin?

    if session[:user].nil? || (!session[:user].id.eql?(params[:id]) && !session[:user].username.eql?(params[:id]))
      redirect_to controller: 'login', action: 'index', redirect: "/accounts/#{params[:id]}"
    end
  end

  def get_ontology_list(ont_hash)
    return "" if ont_hash.nil?
    ontologies = []
    ont_hash.each do |ont, checked|
      ontologies << ont if checked.to_i == 1
    end
    ontologies.join(";")
  end

  def validate(params)
    errors = []
    if params[:email].nil? || params[:email].length < 1 || !params[:email].match(/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i)
      errors << t('users.validate_email_address')
    end
    if params[:password].nil? || params[:password].length < 1
      errors << t('users.validate_password')
    end
    if !params[:password].eql?(params[:password_confirmation])
      errors << t('users.validate_password_confirmation')
    end
    if using_captcha?
      if !verify_recaptcha
        errors << t('users.recaptcha_validation')
      end
    end


    if ((!params[:orcidId].match(/^\d{4}+(-\d{4})+$/)) || (params[:orcidId].length != 19)) && !(params[:orcidId].nil? || params[:orcidId].length < 1)
      errors << t('users.validate_orcid')
    end

    if params[:username].nil? || params[:username].length < 1 || !params[:username].match(/^[a-zA-Z0-9]([._-](?![._-])|[a-zA-Z0-9]){3,18}[a-zA-Z0-9]$/)
      errors << t('users.validate_username')
    end

    unless params[:terms_and_conditions]
      errors << t('users.validate_terms_and_conditions')
    end
    return errors
  end

  def validate_update(params)
    errors = []
    if params[:email].nil? || params[:email].length < 1 || !params[:email].match(/^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/i)
      errors << t('users.valid_email_adresse')
    end
    if params[:firstName].nil? || params[:firstName].length < 1
      errors << t('users.first_name_required')
    end
    if params[:lastName].nil? || params[:lastName].length < 1
      errors << t('users.last_name_required')
    end
    if params[:username].nil? || params[:username].length < 1
      errors << t('users.validate_username')
    end
    if params[:orcidId].present? && ((!params[:orcidId].match(/^\d{4}-\d{4}-\d{4}-\d{4}$/)) || (params[:orcidId].length != 19))
      errors << t('users.validate_orcid')
    end
    if !params[:password].eql?(params[:password_confirmation])
      errors << t('users.validate_password_confirmation')
    end

    return errors
  end

  def update_role(user)
    user_roles = user.role

    if session[:user].admin?
      user_roles = user_roles.dup
      if user.admin?
        user_roles.map!{ |role| role == "ADMINISTRATOR" ? "LIBRARIAN" : role}
      else
        user_roles.map!{ |role| role == "LIBRARIAN" ? "ADMINISTRATOR" : role}
      end
    end

    user_roles
  end

end
