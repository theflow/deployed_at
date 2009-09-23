require File.join(File.dirname(__FILE__), 'test_helper')

class IntegrationTest < Test::Unit::TestCase
  include Webrat::Methods
  include Webrat::Matchers

  def setup
    repository(:default) do
      transaction = DataMapper::Transaction.new(repository)
      transaction.begin
      repository.adapter.push_transaction(transaction)
    end
  end

  def teardown
    repository(:default) do
      while repository.adapter.current_transaction
        repository.adapter.current_transaction.rollback
        repository.adapter.pop_transaction
      end
    end
  end

  test 'should show the dashboard' do
    project = create_project(:name => 'DeployedAt')
    deploy = create_deploy(:title => 'First deploy', :user => 'thedude', :project => project)

    visit '/'

    assert_contain 'DeployedAt'
    assert_contain 'thedude'
  end

  test 'should show a single project' do
    project = create_project(:name => 'DeployedAt')
    deploy = create_deploy(:title => 'First deploy', :user => 'thedude', :project => project)

    visit "/projects/#{project.id}"

    assert_contain 'DeployedAt'
    assert_contain 'First deploy'
  end

  test 'should show a single deploy' do
    deploy = create_deploy(:title => 'First deploy', :user => 'thedude')

    visit "/deploys/#{deploy.id}"

    assert_contain 'First deploy'
    assert_contain 'thedude'
    assert_contain 'changed some stuff'
  end

  test 'should subscriptions page should require a login' do
    visit '/subscriptions'

    assert_equal '/session', current_url
  end

  test 'logging in to access the subscriptions page' do
    user = create_user(:email => 'the@dude.org')
    project1 = create_project(:name => 'DeployedAt')
    project2 = create_project(:name => 'The Dude')
    create_subscription(:user => user, :project => project1)

    # Login
    visit '/subscriptions'
    fill_in 'email', :with => 'the@dude.org'
    click_button 'Log in'

    # Subscription page
    assert field_labeled('DeployedAt').checked?
    assert !field_labeled('The Dude').checked?
  end
end
