module API
  module V1
    describe 'Helpers' do
      before do
        @helpers = Object.new
        @helpers.extend(Helpers)

        @account = FactoryGirl.create(:account, :admin)
        @dummy_env = {
          'current_account' => @account
        }
        allow(@helpers).to receive(:env).and_return(@dummy_env)
      end

      describe '#require_no_authentication' do
        it 'return true when endpoint is /tokens' do
          @dummy_env['api.endpoint'] = double('endpoint', namespace: '/tokens')
          expect(@helpers.require_no_authentication).to be_truthy
        end

        it 'return true when endpoint isn\'t /tokens' do
          @dummy_env['api.endpoint'] = double('endpoint', namespace: '/project')
          expect(@helpers.require_no_authentication).to be_falsy
        end
      end

      describe '#authenticate_account_from_token!' do
        before do
          @dummy_env['current_account'] = nil
          allow(Devise::TokenAuthenticatable).to receive(:token_authentication_key)
          allow(@helpers).to receive(:params).and_return({})
        end

        it 'set current_account to environment when authentication succeed' do
          allow(Account).to receive(:find_for_token_authentication).and_return(@account)
          @helpers.authenticate_account_from_token!
          expect(@helpers.env['current_account']).to eq(@account)
        end

        it 'call error! method when authentication doesn\'t succeed' do
          allow(Account).to receive(:find_for_token_authentication).and_return(nil)
          expect(@helpers).to receive(:error!)
          @helpers.authenticate_account_from_token!
        end
      end

      describe '#authoize!' do
        it 'call Ability#authorize!' do
          expect(@helpers).to receive_message_chain(:create_ability, :authorize!).with(:read, Project)
          @helpers.authorize!(:read, Project)
        end
      end

      describe '#can?' do
        it 'call Ability#can?' do
          expect(@helpers).to receive_message_chain(:create_ability, :can?).with(:read, Project)
          @helpers.can?(:read, Project)
        end
      end

      describe '#cannot?' do
        it 'call Ability#cannot?' do
          expect(@helpers).to receive_message_chain(:create_ability, :cannot?).with(:read, Project)
          @helpers.cannot?(:read, Project)
        end
      end

      describe '#curent_ability' do
        it 'return instance of Ability' do
          allow(@helpers).to receive(:current_account).and_return(@account)
          result = @helpers.current_ability

          expect(result).to be_is_a Ability
        end
      end

      describe '#current_account' do
        it 'return current_account on environment' do
          expect(@helpers.current_account).to eq(@helpers.env['current_account'])
        end
      end

      describe '#declared_params' do
        it 'call declared methods to reject unnecessary parameters' do
          allow(@helpers).to receive(:params)
          expect(@helpers).to receive(:declared).and_return(dummy: 1)
          @helpers.declared_params
        end
      end

      describe '#permitted_params' do
        it 'return params that is filtered with specified columns by StrongParameter ' do
          dummy_params = {
            id: 1,
            name: 'dummy'
          }
          allow(@helpers).to receive(:params).and_return(dummy_params)
          result = @helpers.permitted_params(:name)
          expect(result.keys).to match_array(['name'])
          expect(result.permitted?).to be_truthy
        end
      end
    end
  end
end
