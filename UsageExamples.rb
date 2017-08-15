require_relative 'GeminiAPI'

$apiKey = 'API_KEY'
$secret = 'API_SECRET_KEY'

# Initialize the class
api = GeminiAPI.new($apiKey, $secret, false)

# Returns the current Bitcoin balance in the account
puts api.get_currency_balance('BTC')

# Returns the symbols available at the Exchange as an array
puts api.get_market_symbols.to_s

# Returns the current price of Bitcoin price in USD
puts api.get_ticker_info('btcusd', 'last')

# Returns the current 24 hour volume of Ehereum in ETH and USD along with the last 24 hour end timestamp as a hash
puts api.get_ticker_info('ethusd', 'volume')

# Places a limit buy order of 0.001 Bitcoin at $3000
#puts api.place_order('btcusd', 0.001, 3000, 'buy', 'limit')

# Places a limit sell order of 0.001 Bitcoin at $8000
#puts api.place_order('btcusd', 0.001, 8000, 'sell', 'limit')

# Places a buy order of 0.01 Ehereum at current market price
#puts api.place_order_at_market_price('ethusd', 0.01, 'buy')

# Places a sell order of 0.01 Ehereum at current market price
#puts api.place_order_at_market_price('ethusd', 0.01, 'buy')

# Returns the currently active orders in the account as a hash
#puts api.get_active_orders

# Returns the info for the last 5 Bitcoin trades made in the account as a hash
# puts api.get_past_trades('btcusd', 5)

# Cancels the order with id 5272
#puts api.cancel_order(5272)

# Cancels all the active orders in the account
#puts api.cancel_all_active_orders