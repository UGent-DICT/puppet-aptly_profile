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
    is_expected.to run.with_params(prefix, 'foo' => { 'public' => ['user1'] }).and_return('foo' => { 'public' => ['user1'] })
  end

  context 'expand prefix' do
    it do
      is_expected.to run.with_params(
        prefix,
        'bar' => { 'public' => 'prefix' },
        'foo' => { 'public' => 'prefix' },
      ).and_raise_error(%r{Unable to resolve permissions in prefix '#{prefix}'})
    end

    it do
      is_expected.to run.with_params(
        prefix,
        'foo' => { 'public' => 'prefix' },
        'bar' => { 'public' => ['user0'] },
        'baz' => { 'public' => ['user1'] },
      ).and_return(
        'foo' => { 'public' => ['user0', 'user1'] },
        'bar' => { 'public' => ['user0'] },
        'baz' => { 'public' => ['user1'] },
      )
    end

    it do
      is_expected.to run.with_params(
        prefix,
        'foo' => { 'public' => 'prefix' },
        'bar' => { 'public' => 'authenticated' },
      ).and_return(
        'foo' => { 'public' => 'valid-user' },
        'bar' => { 'public' => 'valid-user' },
      )
    end

    it do
      is_expected.to run.with_params(
        prefix,
        'foo' => { 'public' => 'prefix' },
        'bar' => { 'public' => 'authenticated' },
        'oof' => { 'public' => ['user1'] },
        'baz' => { 'public' => ['user2'] },
      ).and_return(
        'foo' => { 'public' => 'valid-user' },
        'bar' => { 'public' => 'valid-user' },
        'oof' => { 'public' => ['user1'] },
        'baz' => { 'public' => ['user2'] },
      )
    end

    it do
      is_expected.to run.with_params(
        prefix,
        'foo' => {
          'public' => 'prefix',
          'api' => ['admin'],
        },
        'bar' => {
          'public' => 'authenticated',
          'api' => 'authenticated',
        },
      ).and_return(
        'foo' => {
          'public' => 'valid-user',
          'api' => ['admin'],
        },
        'bar' => {
          'public' => 'valid-user',
          'api' => 'valid-user',
        },
      )
    end
  end
end
