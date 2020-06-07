require 'spec_helper'

describe 'aptly_profile::publish_auth_resolve_shared_permissions' do
  describe 'only users' do
    let(:permissions) do
      [
        ['user1', 'user2'],
        ['user3', 'user4'],
        nil,
      ]
    end

    it do
      is_expected.to run.with_params(permissions).and_return(['user1', 'user2', 'user3', 'user4'])
    end
  end

  describe 'with authenticated' do
    let(:permissions) do
      [
        'authenticated',
        ['user1', 'user2'],
        nil,
      ]
    end

    it do
      is_expected.to run.with_params(permissions).and_return('authenticated')
    end
  end

  describe 'with nothing' do
    let(:permissions) { [nil] }

    it do
      is_expected.to run.with_params(permissions).and_return([])
    end
  end
end
