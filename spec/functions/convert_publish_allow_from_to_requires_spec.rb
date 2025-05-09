require 'spec_helper'

describe 'aptly_profile::convert_publish_allow_from_to_requires' do
  let(:default_allow_from) { 'prefix' }
  let(:prefixes) { {} }
  let(:repos) { {} }

  it 'exists' do
    is_expected.not_to be(nil)
  end

  describe 'smoketest' do
    let(:strict) { false }
    let(:repos) do
      {
        'stable' => { 'allow_from' => ['admin'] },
        'publish_limit' => { 'allow_from' => ['userx', 'usery'] },
      }
    end
    let(:publish) do
      {
        'unmanaged/foo' => {},
        'unmanaged/bar' => {},
        'stable' => {
          'allow_from' => ['prduser'],
          'components' => {
            'foo' => { 'repo' => 'stable' },
          },
        },
        'testing' => { 'allow_from' => 'authenticated' },
        'foo/test' => { 'allow_from' => ['user1'] },
        'foo/bar' => { 'allow_from' => ['user2'] },
        'foo/baz' => { 'allow_from' => 'prefix' },
        'bar/shared' => { 'allow_from' => 'authenticated' },
        'bar/user' => { 'allow_from' => ['user3'] },
        'bar/undefined' => {},
        'public/publish_auth' => {
          'components' => { 'main' => { 'repo' => 'publish_limit' } },
        },
      }
    end

    it 'generates an authorization scheme' do
      is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict).and_return(
        '' => {
          'api' => ['admin'], # limit post
          'pool' => 'valid-user',
          'dists' => {
            'stable' => {
              'api' => ['admin'],
              'public' => ['prduser'],
            },
            'testing' => {
              'public' => 'valid-user',
            },
          },
        },
        'bar' => {
          'pool' => 'valid-user',
          'dists' => {
            'shared' => { 'public' => 'valid-user' },
            'undefined' => { 'public' => 'valid-user' },
            'user' => { 'public' => ['user3'] },
          },
        },
        'foo' => {
          'pool' => ['user1', 'user2'],
          'dists' => {
            'bar' => { 'public' => ['user2'] },
            'baz' => { 'public' => ['user1', 'user2'] },
            'test' => { 'public' => ['user1'] },
          },
        },
        'public' => {
          'api' => ['userx', 'usery'],
          'dists' => {
            'publish_auth' => { 'api' => ['userx', 'usery'] },
          },
        },
      )
    end
  end

  context 'generating configuration' do
    [true, false].each do |strict|
      context "strict: #{strict}" do
        let(:strict) { strict }

        describe 'empty' do
          let(:publish) { {} }

          it do
            is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict).and_return({})
          end
        end

        context 'user resolving' do
          describe 'same user' do
            let(:publish) do
              {
                'foo' => { 'allow_from' => ['user1'] },
                'bar' => { 'allow_from' => ['user1'] },
              }
            end

            it do
              is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict).and_return(
                '' => {
                  'pool' => ['user1'],
                  'dists' => {
                    'foo' => { 'public' => ['user1'] },
                    'bar' => { 'public' => ['user1'] },
                  },
                },
              )
            end
          end

          describe 'different over distributions' do
            let(:publish) do
              {
                'foo' => { 'allow_from' => ['user1'] },
                'bar' => { 'allow_from' => ['user2'] },
              }
            end

            if strict
              it 'fails when strict' do
                pending 'strict validation not implemented yet'
                is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict).and_raise_error(
                  %r{Found difference in users within prefix '' with strict enabled},
                )
              end
            else
              it 'merges the users' do
                is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict).and_return(
                  '' => {
                    'pool' => ['user1', 'user2'],
                    'dists' => {
                      'foo' => { 'public' => ['user1'] },
                      'bar' => { 'public' => ['user2'] },
                    },
                  },
                )
              end
            end
          end
        end

        describe 'authenticated only' do
          let(:publish) do
            {
              'foo' => { 'allow_from' => 'authenticated' },
              'bar' => { 'allow_from' => 'authenticated' },
            }
          end

          it do
            is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict).and_return(
              '' => {
                'pool' => 'valid-user',
                'dists' => {
                  'foo' => { 'public' => 'valid-user' },
                  'bar' => { 'public' => 'valid-user' },
                },
              },
            )
          end
        end

        describe 'prefix only' do
          let(:publish) do
            {
              'foo' => { 'allow_from' => 'prefix' },
              'bar' => { 'allow_from' => 'prefix' },
            }
          end

          it do
            is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict)
                              .and_raise_error(%r{Unable to resolve permissions in prefix ''})
          end
        end

        describe 'authenticated and users' do
          let(:publish) do
            {
              'prefix/authenticated' => {
                'allow_from' => 'authenticated',
              },
              'prefix/users' => {
                'allow_from' => ['user1'],
              },
            }
          end

          if strict
            it 'fails when strict' do
              pending 'strict validation not implemented yet'
              is_expected.to run
                .with_params(publish, prefixes, repos, default_allow_from, strict)
                .and_raise_error(%r{Found difference in users within prefix 'prefix' with strict enabled})
            end
          else
            it do
              is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict).and_return(
                'prefix' => {
                  'pool' => 'valid-user',
                  'dists' => {
                    'authenticated' => { 'public' => 'valid-user' },
                    'users' => { 'public' => ['user1'] },
                  },
                },
              )
            end
          end
        end

        describe 'authenticated and prefix' do
          let(:publish) do
            {
              'prefix/authenticated' => {
                'allow_from' => 'authenticated',
              },
              'prefix/prefixed' => {
                'allow_from' => 'prefix',
              },
            }
          end

          it do
            is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict).and_return(
              'prefix' => {
                'pool' => 'valid-user',
                'dists' => {
                  'authenticated' => { 'public' => 'valid-user' },
                  'prefixed' => { 'public' => 'valid-user' },
                },
              },
            )
          end
        end

        describe 'users and prefix' do
          let(:publish) do
            {
              'prefix/users' => {
                'allow_from' => ['user1', 'user2'],
              },
              'prefix/also_users' => {
                'allow_from' => ['user3', 'user2'],
              },
              'prefix/prefixed' => {
                'allow_from' => 'prefix',
              },
            }
          end

          if strict
            it 'fails when strict' do
              pending 'strict validation not implemented yet'
              is_expected.to run
                .with_params(publish, prefixes, repos, default_allow_from, strict)
                .and_raise_error(%r{Found difference in users within prefix 'prefix' with strict enabled})
            end
          else
            it do
              is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict).and_return(
                'prefix' => {
                  'pool' => ['user1', 'user2', 'user3'],
                  'dists' => {
                    'also_users' => { 'public' => ['user2', 'user3'] },
                    'prefixed' => { 'public' => ['user1', 'user2', 'user3'] },
                    'users' => { 'public' => ['user1', 'user2'] },
                  },
                },
              )
            end
          end
        end

        describe 'remove \'unmanaged\' prefixes' do
          let(:publish) do
            {
              'unmanaged/one' => {},
              'unmanaged/two' => {},
              'stable' => { 'allow_from' => ['user'] },
            }
          end

          it do
            is_expected.to run.with_params(publish, prefixes, repos, default_allow_from, strict).and_return(
              '' => {
                'pool' => ['user'],
                'dists' => {
                  'stable' => { 'public' => ['user'] },
                },
              },
            )
          end
        end
      end
    end
  end
end
