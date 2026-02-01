# Bitget API V2 Specification

## Base URLs
- Primary: https://api.bitget.com
- Secondary: https://capi.bitget.com

## Authentication

### Required Headers
- `ACCESS-KEY`: The API Key
- `ACCESS-SIGN`: The signature (see below)
- `ACCESS-TIMESTAMP`: Request timestamp
- `ACCESS-PASSPHRASE`: The passphrase you specified when creating the API key

### Signature Calculation
The signature is a Base64 encoded HMAC SHA256 hash:

```
signature = base64(hmac_sha256(secret_key, message))
message = timestamp + method + request_path + query_string + body
```

Where:
- `timestamp`: Same as ACCESS-TIMESTAMP header
- `method`: HTTP method in uppercase (GET, POST, etc.)
- `request_path`: Path without domain (e.g., `/api/v2/spot/account/assets`)
- `query_string`: Query parameters (without ?)
- `body`: Request body (empty string for GET requests)

## Key Endpoints

### Public

#### Server Time
```
GET /api/v2/public/time
```

Response:
- `serverTime`: Current server timestamp

### Spot Trading

#### Account Balance
```
GET /api/v2/spot/account/assets
```

Optional Parameters:
- `coin`: Filter by specific coin (e.g., "BTC")

Response includes:
- `coin`: Coin name
- `available`: Available balance
- `frozen`: Frozen balance
- `locked`: Locked balance

#### Market Tickers
```
GET /api/v2/spot/market/tickers
```

Optional Parameters:
- `symbol`: Trading pair (e.g., "BTCUSDT")

Response includes:
- `symbol`: Trading pair
- `lastPr`: Last price
- `high24h`: 24h high
- `low24h`: 24h low
- `change24h`: 24h change percentage

### Futures Trading (Mix)

#### Account Information
```
GET /api/v2/mix/account/accounts
```

Parameters:
- `productType`: Product type (USDT-FUTURES, COIN-FUTURES, USDC-FUTURES)

#### Open Positions
```
GET /api/v2/mix/position/all-position
```

Parameters:
- `productType`: Product type (USDT-FUTURES, COIN-FUTURES, USDC-FUTURES)
- `marginCoin`: Optional filter

Response includes:
- `symbol`: Trading pair
- `marginCoin`: Margin currency
- `holdSide`: Position side (long/short)
- `margin`: Position margin
- `available`: Available quantity
- `locked`: Locked quantity
- `total`: Total position
- `leverage`: Leverage ratio
- `achievedProfits`: Realized PnL
- `unrealizedPL`: Unrealized PnL
- `liquidationPrice`: Liquidation price
- `markPrice`: Mark price
- `marketPrice`: Market price
- `averageOpenPrice`: Average entry price

#### Market Ticker
```
GET /api/v2/mix/market/ticker
```

Parameters:
- `symbol`: Trading pair
- `productType`: Product type

Response includes:
- `lastPr`: Last price

#### Product Types
- `USDT-FUTURES`: USDT perpetual
- `COIN-FUTURES`: Coin margined perpetual
- `USDC-FUTURES`: USDC perpetual

## Rate Limits
- Most endpoints: 10-20 requests/second
- HTTP 429 status code when limit exceeded
- Limits are per UID or IP

## Response Format
Standard JSON response with:
- `code`: Error code ("00000" for success)
- `msg`: Error message
- `requestTime`: Request timestamp
- `data`: Response data (often an array in V2)

## Error Codes
- "00000": Success
- 429: Rate limit exceeded
- Various other codes for authentication failures, invalid parameters, etc.

## API Key Permissions
- Read: Query market data and account info
- Trade: Place and cancel orders
- Transfer: Transfer between accounts
- Withdraw: Withdraw assets (requires whitelisted IP)
