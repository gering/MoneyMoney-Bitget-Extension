# Bitget API Specification

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
- `request_path`: Path without domain (e.g., `/api/spot/v1/account/assets`)
- `query_string`: Query parameters (without ?)
- `body`: Request body (empty string for GET requests)

## Key Endpoints

### Spot Trading

#### Account Balance
```
GET /api/spot/v1/account/assets
```

Optional Parameters:
- `coin`: Filter by specific coin (e.g., "BTC")

Response includes:
- `available`: Available balance
- `frozen`: Frozen balance
- `locked`: Locked balance

#### Account Balance (Lite)
```
GET /api/spot/v1/account/assets-lite
```

Similar to assets endpoint but defaults to showing only non-zero balances.

### Futures Trading (Mix)

#### Account Information
```
GET /api/mix/v1/account/account
GET /api/mix/v1/account/accounts
```

Parameters:
- `symbol`: Trading pair (e.g., "BTCUSDT_UMCBL")
- `marginCoin`: Margin coin (e.g., "USDT")

#### Open Positions
```
GET /api/mix/v1/position/allPosition
GET /api/mix/v1/position/allPosition-v2
```

Parameters:
- `productType`: Product type (umcbl, dmcbl, cmcbl, sumcbl)
- `marginCoin`: Optional filter

Response includes:
- `symbol`: Trading pair
- `marginCoin`: Margin currency
- `holdSide`: Position side (long/short)
- `openDelegateCount`: Number of open orders
- `margin`: Position margin
- `available`: Available quantity
- `locked`: Locked quantity
- `total`: Total position
- `leverage`: Leverage ratio
- `achievedProfits`: Realized PnL
- `unrealizedPL`: Unrealized PnL
- `unrealizedPLR`: Unrealized PnL ratio
- `liquidationPrice`: Liquidation price
- `keepMarginRate`: Maintenance margin rate
- `markPrice`: Mark price
- `averageOpenPrice`: Average entry price

#### Product Types
- `umcbl`: USDT perpetual
- `dmcbl`: Universal margin
- `cmcbl`: USDC perpetual
- `sumcbl`: USDT perpetual demo

## Rate Limits
- Most endpoints: 10-20 requests/second
- HTTP 429 status code when limit exceeded
- Limits are per UID or IP

## Response Format
Standard JSON response with:
- `code`: Error code (0 for success)
- `msg`: Error message
- `data`: Response data

## Error Codes
- 0: Success
- 429: Rate limit exceeded
- Various other codes for authentication failures, invalid parameters, etc.

## API Key Permissions
- Read: Query market data and account info
- Trade: Place and cancel orders
- Transfer: Transfer between accounts
- Withdraw: Withdraw assets (requires whitelisted IP)