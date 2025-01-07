import ccxt


exchange = ccxt.binance(
    {
        "apiKey": "08z19XTKxLRGtJYL4UtlCqkYUbeumsQNQKy2s9B73NtGM89YPBxsxvzCePsp1ueK",
        "secret": "cpbEmhO3TSJoVZIuPhCc0Hk1rlqTUSg0dAp7p5XJKycph4Dzga5wue8v2Xr6P7XN",
        "uid": "173109531",
    }
)

# Fetch balances
try:
    balance = exchange.fetch_balance()
    print(balance)
except Exception as e:
    print(f"Error: {e}")
