require 'open-uri'
require 'json'
require 'base64'
require 'OpenSSL'
require 'net/http'
require 'date'

class GeminiAPI

  # Takes the API Key, API Secret Key, and sandbox conditional and initializes the class
  def initialize(apiKey, apiSecret, sandbox=false)
    @@apiKey = apiKey
    @@apiSecret = apiSecret

    if sandbox
      @@apiBaseURL = 'https://api.sandbox.gemini.com'
    else
      @@apiBaseURL = 'https://api.gemini.com'
    end
  end


  # Takes a URL and sends a request using HTTP Get
  def http_request(url)
    begin
      request = open(url, :read_timeout => 600)

      return JSON.parse(request.read)
    rescue => e
      puts e.message
    end
  end


  # Takes a URL and headers, and sends a request using HTTP Post
  def http_post(url, headers)
    begin
      uri = URI.parse(url)

      https = Net::HTTP.new(uri.host, uri.port)
      https.use_ssl = true
      request = Net::HTTP::Post.new(uri.path, headers)
      response = https.request(request)

      return JSON.parse(response.body)
    rescue => e
      puts e.message
    end
  end

  # Returns the market symbols at the exchange as a hash
  def get_market_symbols
    requestURL = '/v1/symbols'

    return http_request(@@apiBaseURL + requestURL)
  end

  # Returns a hash containing the available balance of all the currencies in the acccount
  def get_available_balances()
    requestURL = '/v1/balances'

    data = {'request' => requestURL, 'nonce' => DateTime.now.strftime('%Q')}

    payload = Base64.strict_encode64(JSON.generate(data))
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha384'), @@apiSecret, payload)

    headers = {'Content-Length' => '0', 'Content-Type' => 'text/plain', 'X-GEMINI-APIKEY' => @@apiKey,
               'X-GEMINI-PAYLOAD' => payload, 'X-GEMINI-SIGNATURE' => signature}

    return http_post(@@apiBaseURL + requestURL, headers)
  end


  # Takes a currency and returns its balance in the account
  # Currencies: 'BTC', 'ETH', 'USD'
  def get_currency_balance(currency)
    balances = get_available_balances()

    for type in balances
      if (type['currency'] == currency)
        return type['amount']
      end
    end
  end

  # Returns the notional value of the account
  def get_notional_account_value
    balances = get_available_balances
    notional_value = 0.0

    for type in balances
      if type['currency'] == 'BTC'
        notional_value += type['amount'].to_f * get_ticker_info('btcusd', 'last').to_f
      elsif type['currency'] == 'ETH'
        notional_value += type['amount'].to_f * get_ticker_info('ethusd', 'last').to_f
      elsif type['currency'] == 'USD'
        notional_value += type['amount'].to_f
      end
    end

    return notional_value

  end


  # Takes a currency symbol and the information type and returns that information for that currency symbol
  # Currencies Symbols: btcusd, ethusd, ethbtc
  # Types: 'last' (last price), 'bid' (current highest bid), 'asks' (current lowest bid), 'volume'
  def get_ticker_info(symbol, type)
    requestURL = '/v1/pubticker/' + symbol

    return http_request(@@apiBaseURL + requestURL)[type]
  end


  # Takes a symbol, decimal purchase/sell quantity, decimal price, transaction type and order type, and places the order and returns the order details
  # Transaction Types: 'buy', 'sell'
  # Order Types: 'limit', 'maker-or-cancel' (adds liquidity), 'immediate-or-cancel' (removes liquidity)
  def place_order(symbol, quantity, price, transactionType, orderType)
    requestURL = '/v1/order/new'
    amount = amount.to_f.to_s
    price = price.to_f.to_s

    data = {'request' => requestURL, 'nonce' => DateTime.now.strftime('%Q'), 'symbol' => symbol, 'amount' => quantity, 'price' => price,
            'side' => transactionType, 'type' => 'exchange limit'}

    if orderType != 'limit'
      data['options'] = [orderType]
    end

    payload = Base64.strict_encode64(JSON.generate(data))
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha384'), @@apiSecret, payload)

    headers = {'Content-Length' => '0', 'Content-Type' => 'text/plain', 'X-GEMINI-APIKEY' => @@apiKey,
               'X-GEMINI-PAYLOAD' => payload, 'X-GEMINI-SIGNATURE' => signature}

    return http_post(@@apiBaseURL + requestURL, headers)
  end


  # Takes a symbol, decimal purchase/sell quantity and transaction type, and places the order for the coin at current market price and returns the order details
  # Currency Symbols: 'btcusd', 'ethusd', 'btceth'
  # Transaction Types: 'buy', 'sell'
  def place_order_at_market_price(symbol, quantity, transactionType)
    begin
      last_price = get_ticker_info(symbol, 'last').to_f

      # Set the price with really high limit values so that the order gets placed for sure even if the price fluctuates a little
      if symbol == 'btcusd'
        limitPrice = 200.0
      elsif symbol == 'ethusd'
        limitPrice = 30.0
      elsif symbol == 'ethbtc'
        limitPrice = 0.01
      else
        raise 'Error in place_order_at_market_price(): Invalid symbol'
      end

      if transactionType == 'buy'
        price = last_price + limitPrice
      elsif transactionType == 'sell'
        price = last_price - limitPrice
      else
        raise "Error in place_order_at_market_price(): Invalid transaction type"
      end

      if price < 0
        price = 0.0
      end

      return place_order(symbol, quantity, price, transactionType, 'limit')

    rescue => s
      puts s.message
    end
  end

  # Returns the currently active orders in the account
  def get_active_orders
    requestURL = '/v1/orders'

    data = {'request' => requestURL, 'nonce' => DateTime.now.strftime('%Q')}

    payload = Base64.strict_encode64(JSON.generate(data))
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha384'), @@apiSecret, payload)

    headers = {'Content-Length' => '0', 'Content-Type' => 'text/plain', 'X-GEMINI-APIKEY' => @@apiKey,
               'X-GEMINI-PAYLOAD' => payload, 'X-GEMINI-SIGNATURE' => signature}

    return http_post(@@apiBaseURL + requestURL, headers)
  end

  # Takes a symbol and a size limit and returns the past trades in the account
  def get_past_trades(symbol, size)
    requestURL = '/v1/mytrades'

    data = {'request' => requestURL, 'nonce' => DateTime.now.strftime('%Q'), 'symbol' => symbol, 'limit_trades' => size}

    payload = Base64.strict_encode64(JSON.generate(data))
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha384'), @@apiSecret, payload)

    headers = {'Content-Length' => '0', 'Content-Type' => 'text/plain', 'X-GEMINI-APIKEY' => @@apiKey,
               'X-GEMINI-PAYLOAD' => payload, 'X-GEMINI-SIGNATURE' => signature}

    return http_post(@@apiBaseURL + requestURL, headers)
  end

  # Takes an order id, cancels the order, and then returns the order details after cancellation
  def cancel_order(id)
    requestURL = '/v1/order/cancel'

    data = {'request' => requestURL, 'nonce' => DateTime.now.strftime('%Q'), 'order_id' => id}

    payload = Base64.strict_encode64(JSON.generate(data))
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha384'), @@apiSecret, payload)

    headers = {'Content-Length' => '0', 'Content-Type' => 'text/plain', 'X-GEMINI-APIKEY' => @@apiKey,
               'X-GEMINI-PAYLOAD' => payload, 'X-GEMINI-SIGNATURE' => signature}

    return http_post(@@apiBaseURL + requestURL, headers)
  end

  # Cancels all active orders in the account and returns the status of the cancellation request
  def cancel_all_active_orders
    requestURL = '/v1/order/cancel/all'

    data = {'request' => requestURL, 'nonce' => DateTime.now.strftime('%Q')}

    payload = Base64.strict_encode64(JSON.generate(data))
    signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha384'), @@apiSecret, payload)

    headers = {'Content-Length' => '0', 'Content-Type' => 'text/plain', 'X-GEMINI-APIKEY' => @@apiKey,
               'X-GEMINI-PAYLOAD' => payload, 'X-GEMINI-SIGNATURE' => signature}

    return http_post(@@apiBaseURL + requestURL, headers)
  end

end