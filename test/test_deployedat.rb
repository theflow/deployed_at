require File.join(File.dirname(__FILE__), 'test_helper')

class DeployTest < Test::Unit::TestCase

  test 'number of changeset should be zero if zero changesets exist' do
    deploy = Deploy.new(:body => '')
    assert_equal 0, deploy.get_number_of_changes

    deploy = Deploy.new(:body => nil)
    assert_equal 0, deploy.get_number_of_changes
  end

  test 'number of changesets should be one for one changeset' do
    deploy = Deploy.new(:body => File.read('changesets/one_changeset.txt'))
    assert_equal 1, deploy.get_number_of_changes
  end

  test 'number of changesets should be a lot for many changesets' do
    deploy = Deploy.new(:body => File.read('changesets/two_changesets.txt'))
    assert_equal 2, deploy.get_number_of_changes
  end

end