require "application_system_test_case"

class LoginFlowsTest < ApplicationSystemTestCase

  setup do
    WebMock.disable!
    @user_john = fixtures(:users)[:john]
    @user_bob = fixtures(:users)[:bob]
  end

  teardown do
    delete_user(@user_bob)
    delete_user(@user_john)
  end

  test "go to sign up page, save and see account details" do
    visit root_url
    click_on 'Login'

    click_on 'Register'

    new_user = @user_john
    delete_user(new_user)

    fill_in 'user_firstName', with: new_user.firstName
    fill_in 'user_lastName', with: new_user.lastName
    fill_in 'user_username', with: new_user.username
    fill_in 'user_orcidId', with: new_user.orcidId
    fill_in 'user_githubId', with: new_user.githubId
    fill_in 'user_email', with: new_user.email
    fill_in 'user_password', with: new_user.password
    fill_in 'user_password_confirmation', with: new_user.password
    find("input[name='user[terms_and_conditions]']").set(true)

    # Click the save button
    click_button 'Register'


    assert_selector '.notification', text: 'Account was successfully created'

    visit root_url + "/accounts/#{new_user.username}"

    assert_selector '.account-page-title', text:  'My account'

    assert_selector '.title', text: 'First name:'
    assert_selector '.info', text: new_user.firstName

    assert_selector '.title', text: 'Last name:'
    assert_selector '.info', text: new_user.lastName

    assert_selector '.title', text: 'Email:'
    assert_selector '.info', text: new_user.email

    assert_selector '.title', text: 'Username:'
    assert_selector '.info', text: new_user.username

    assert_selector '.title', text: 'ORCID:'
    assert_selector '.info', text: new_user.orcidId

    assert_selector '.title', text: 'GitHub account:'
    assert_selector '.info', text: new_user.githubId

    assert_selector '.account-page-card-title', text: 'API Key'
    assert_selector '.account-page-card-title', text: 'Subscriptions'
    assert_selector '.account-page-card-title', text: 'Submitted ontologies'
    assert_selector '.account-page-card-title', text: 'Projects created'
  end

  test "go to login page and click save" do
    login_in_as(@user_bob)

    assert_selector '.notification', text: "Welcome #{@user_bob.username}!", wait: 10
  end

  test "login and reset password" do
    login_in_as(@user_bob)

    visit root_url + "/accounts/#{@user_bob.username}"

    find("a[href=\"#{edit_user_path(@user_bob.username)}\"]").click

    click_on 'Change password'

    fill_in 'user_password', with: "new password"
    fill_in 'user_password_confirmation', with: "new password"

    click_on 'Save'

    # The click returns before the update lands: wait for it before asking
    # the API
    assert_text I18n.t('users.account_successfully_updated')

    logged_in_user = LinkedData::Client::Models::User.authenticate(@user_bob.username, "new password")

    assert logged_in_user && !logged_in_user.errors
  end

end
