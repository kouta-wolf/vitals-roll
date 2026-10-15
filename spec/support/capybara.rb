# system spec のドライバ設定(#195)
#
# - CI（GitHub Actions）: ランナーに入っている Chrome をヘッドレスで使う
# - どちらでもない場合はスキップする
# - Docker: web コンテナには Chrome が無いため、chrome サービス（selenium/standalone-chromium）へ
#   リモート接続する。ブラウザは別コンテナで動くので、テスト用サーバをコンテナのIPで公開する。
#
#   docker compose --profile system up -d chrome
#   docker compose run --rm -e RAILS_ENV=test -e SELENIUM_REMOTE_URL=http://chrome:4444 web bundle exec rspec spec/system
RSpec.configure do |config|
  config.before(:each, type: :system) do
    if ENV["SELENIUM_REMOTE_URL"].present?
      driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ],
                           options: { browser: :remote, url: ENV["SELENIUM_REMOTE_URL"] }
      Capybara.server_host = "0.0.0.0"
      Capybara.server_port = 4000
      Capybara.app_host = "http://#{IPSocket.getaddress(Socket.gethostname)}:#{Capybara.server_port}"
    elsif ENV["CI"].present?
      driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1000 ]
    else
      # web コンテナには Chrome が無く、そのまま実行すると全件ブラウザ起動エラーになる。
      # 普段の bundle exec rspec を通るようにしておき、system spec は明示的に実行する
      skip "SELENIUM_REMOTE_URL が未設定のため system spec をスキップします（実行方法は spec/support/capybara.rb を参照）"
    end
  end
end
