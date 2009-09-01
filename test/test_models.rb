require File.join(File.dirname(__FILE__), 'test_helper')

class DeployTest < Test::Unit::TestCase

  test 'number of changeset should be zero if zero changesets exist' do
    deploy = Deploy.new(:scm_log => '')
    assert_equal 0, deploy.get_number_of_changes

    deploy = Deploy.new(:scm_log => nil)
    assert_equal 0, deploy.get_number_of_changes
  end

  test 'number of changesets should be one for one changeset' do
    deploy = Deploy.new(:scm_log => File.read('changesets/one_changeset.txt'))
    assert_equal 1, deploy.get_number_of_changes
  end

  test 'number of changesets should be a lot for many changesets' do
    deploy = Deploy.new(:scm_log => File.read('changesets/two_changesets.txt'))
    assert_equal 2, deploy.get_number_of_changes
  end

  test 'should create multiple subscriptions' do
    user = User.create
    project1 = Project.create(:name => 'project_1')
    project2 = Project.create(:name => 'project_2')

    user.manage_subscriptions({ project1.id.to_s => 'on', project2.id.to_s => 'on' })

    user.reload
    assert user.projects.include?(project1)
    assert user.projects.include?(project2)
  end

  test 'should not create multiple subscriptions' do
    user = User.create
    project1 = Project.create(:name => 'project_1')
    project2 = Project.create(:name => 'project_2')
    Subscription.create(:project => project1, :user => user)

    user.manage_subscriptions({ project1.id.to_s => 'on', project2.id.to_s => 'on' })

    user.reload
    assert_equal 2, user.subscriptions.size
    assert user.projects.include?(project1)
    assert user.projects.include?(project2)
  end

  test 'should create and destroy subscriptions' do
    user = User.create
    project1 = Project.create(:name => 'project_1')
    project2 = Project.create(:name => 'project_2')
    Subscription.create(:project => project1, :user => user)

    user.manage_subscriptions({ project2.id.to_s => 'on' })

    user.reload
    assert_equal 1, user.subscriptions.size
    assert user.projects.include?(project2)
  end

  test 'should not email anything when there are no subscriptions' do
    project = Project.create(:name => 'project_1')

    DeployMailer.expects(:send_by_smtp).never
    project.deploys.create(:title => 'title', :user => 'user', :scm_log => 'log', :head_rev => '42', :current_rev => '23')
  end

  test 'should notify subscribers for a new deploy' do
    project1 = Project.create(:name => 'project_1')
    project2 = Project.create(:name => 'project_2')
    Subscription.create(:project => project1, :user => User.create(:email => 'user1@test.com'))
    Subscription.create(:project => project2, :user => User.create(:email => 'user2@test.com'))

    DeployMailer.expects(:send_by_smtp).with(anything, anything, ['user1@test.com']).once
    project1.deploys.create(:title => 'title', :user => 'user', :scm_log => 'log', :head_rev => '42', :current_rev => '23')
  end
end
