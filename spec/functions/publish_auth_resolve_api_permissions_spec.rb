require 'spec_helper'

describe 'aptly_profile::publish_auth_resolve_api_permissions' do
  let(:repos) do
    {
      'repouserx' => { 'allow_from' => ['userx'] },
      'repousery' => { 'allow_from' => ['usery'] },
      'repoany' => { 'allow_from' => 'authenticated' },
    }
  end

  describe 'single repo' do
    let(:publish_params) do
      {
        'allow_from' => ['foobar'],
        'components' => {
          'main' => {
            'repo' => 'repoany',
          },
        },
      }
    end

    it do
      is_expected.to run.with_params(publish_params, repos).and_return('authenticated')
    end
  end

  describe 'multiple repos' do
    describe 'mixed users' do
      let(:publish_params) do
        {
          'allow_from' => ['foobar'],
          'components' => {
            'componentx' => {
              'repo' => 'repouserx',
            },
            'componenty' => {
              'repo' => 'repousery',
            },
          },
        }
      end

      it do
        is_expected.to run.with_params(publish_params, repos).and_return(['userx', 'usery'])
      end
    end

    describe 'mixed authenticated' do
      let(:publish_params) do
        {
          'allow_from' => ['foobar'],
          'components' => {
            'componentx' => {
              'repo' => 'repouserx',
            },
            'componenta' => {
              'repo' => 'repoany',
            },
          },
        }
      end

      it do
        is_expected.to run.with_params(publish_params, repos).and_return('authenticated')
      end
    end
  end
end
