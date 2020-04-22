require 'spec_helper'

describe 'aptly_profile::publish_auth_resolve_permissions_by_prefix' do
  let(:prefix) { 'testprefix' }

  it do
    is_expected.not_to eq(nil)
  end

  it do
    is_expected.to run.with_params(prefix).and_raise_error(ArgumentError, %r{expects 2 arguments})
  end

  it do
    is_expected.to run.with_params(prefix, {}).and_raise_error(ArgumentError, %r{parameter 'distributions' expects size})
  end

  it do
    is_expected.to run.with_params(prefix, 'bogus' => 'foobar').and_raise_error(ArgumentError, %r{expects an Aptly_profile::DistroPermissions})
  end

  it do
    is_expected.to run.with_params(prefix, 'foo' => ['user1']).and_return('foo' => ['user1'])
  end

  context 'expand prefix' do
    it do
      is_expected.to run.with_params(prefix,                                        'bar' => 'prefix',
                                                                                    'foo' => 'prefix').and_raise_error(%r{Unable to resolve permissions in prefix '#{prefix}'})
    end

    it do
      is_expected.to run.with_params(prefix,                                        'foo' => 'prefix',
                                                                                    'bar' => ['user0'],
                                                                                    'baz' => ['user1']).and_return('foo' => ['user0', 'user1'],
                                                                                                                   'bar' => ['user0'],
                                                                                                                   'baz' => ['user1'])
    end

    it do
      is_expected.to run.with_params(prefix,                                        'foo' => 'prefix',
                                                                                    'bar' => 'authenticated').and_return('foo' => 'valid-user',
                                                                                                                         'bar' => 'valid-user')
    end

    it do
      is_expected.to run.with_params(prefix,                                        'foo' => 'prefix',
                                                                                    'bar' => 'authenticated',
                                                                                    'oof' => ['user1'],
                                                                                    'baz' => ['user2']).and_return('foo' => 'valid-user',
                                                                                                                   'bar' => 'valid-user',
                                                                                                                   'oof' => ['user1'],
                                                                                                                   'baz' => ['user2'])
    end
  end
end
