# Bitget API Specification (REST, v2)

This repository targets **Bitget REST API v2** endpoints. Some v1 endpoints are deprecated/decommissioned and may return errors; use v2 for new integrations.

## Base URLs
- Primary: https://api.bitget.com
- Secondary: https://capi.bitget.com

## Authentication

### Required Headers (private/signed endpoints)
- `ACCESS-KEY`: The API key
- `ACCESS-SIGN`: The signature (see below)
- `ACCESS-TIMESTAMP`: Request timestamp in **milliseconds** since Unix epoch (string)
- `ACCESS-PASSPHRASE`: The passphrase you specified when creating the API key
- `Content-Type`: `application/json`
- Optional: `locale`: e.g. `en-US`

Public endpoints do **not** require these headers. Private endpoints require signing and the headers above.

### Timestamp requirements
Bitget validates `ACCESS-TIMESTAMP` against server time. If your local clock is too far off (commonly > ~30 seconds), signed requests may fail. Prefer syncing system time or using server time for troubleshooting (`GET /api/v2/public/time`).

### Signature Calculation
The signature is a Base64 encoded HMAC SHA256 hash:

```
signature = base64(hmac_sha256(secret_key, prehash))
```

`prehash` is constructed as:

```
prehash = timestamp + UPPER(method) + request_path + query_part + body
query_part = (query_string == "" ? "" : "?" + query_string)
body = "" for GET (or empty string if no JSON body)
```

Where:
- `timestamp`: Same as the `ACCESS-TIMESTAMP` header (milliseconds as string)
- `method`: HTTP method in uppercase (GET, POST, etc.)
- `request_path`: Path without domain (e.g., `/api/v2/spot/account/assets`)
- `query_string`: URL-encoded query parameters **without** the leading `?`
- `body`: Request body string (empty for GET)

Important:
- The `query_string` included in the signature must match the query string used in the request URL (including URL encoding).
- Build the query string deterministically to avoid signature mismatches (e.g., sort parameter keys before concatenation, then URL-encode keys/values).

## Key Endpoints

### Public

#### Server time
```
GET /api/v2/public/time
```

### Spot Trading

#### Account Balance / Assets (private)
```
GET /api/v2/spot/account/assets
```

Query parameters (common):
- `assetType` (optional): scope of returned assets
  - `hold_only`: non-zero balances only
  - `all`: all assets
- `coin` (optional): filter by specific coin (e.g., `BTC`)

Response includes (commonly used `data[]` fields):
- `coin`
- `available`
- `frozen`
- `locked`
- `limitAvailable`

#### Market Tickers (public)
```
GET /api/v2/spot/market/tickers
```

Query parameters:
- `symbol` (optional): e.g. `BTCUSDT` (if omitted, returns multiple tickers)

Response includes (commonly used `data[]` fields):
- `symbol`
- `lastPr`
- `bidPr`
- `askPr`
- `high24h`
- `low24h`
- `ts`

### Futures Trading (Mix)

#### Account Information (private)
```
GET /api/v2/mix/account/accounts
```

Query parameters:
- `productType` (required)

Common `productType` values (v2):
- `USDT-FUTURES`: USDT-margined futures
- `USDC-FUTURES`: USDC-margined futures
- `COIN-FUTURES`: coin-margined futures

Response includes (commonly used `data[]` fields):
- `marginCoin`
- `available`
- `accountEquity`
- `locked`
- `crossedMaxAvailable`
- `isolatedMaxAvailable`
- `maxTransferOut`
- `assetMode`

#### Open Positions / All Positions (private)
```
GET /api/v2/mix/position/all-position
```

Query parameters:
- `productType` (required)
- `marginCoin` (optional): filter by margin coin (e.g., `USDT`)

Response includes (commonly used `data[]` fields):
- `symbol`
- `marginCoin`
- `holdSide` (long/short)
- `total`
- `available`
- `locked`
- `leverage`
- `marginMode`
- `marginSize`
- `unrealizedPL`
- `achievedProfits`
- `markPrice`
- `openPriceAvg`
- `cTime`
- `uTime`

#### Market Ticker (public)
```
GET /api/v2/mix/market/ticker
```

Query parameters:
- `productType` (required)
- `symbol` (required)

Response includes (commonly used `data[]` fields):
- `symbol`
- `lastPr`
- `bidPr`
- `askPr`
- `markPrice`
- `ts`

## Rate Limits
Rate limits are endpoint-specific. If you hit limits, expect HTTP 429 responses and/or API error codes.

## Response Format
Standard JSON response with:
- `code`: API status code (typically `"00000"` for success)
- `msg` (or `message`): status message
- `data`: response data
- `requestTime`: server timestamp (ms)

## Error Codes
Examples:
- `"00000"`: Success
- HTTP 429: Rate limit exceeded
- Other codes indicate authentication failures, invalid parameters, permissions, etc.

## API Key Permissions
Recommended for read-only portfolio integrations:
- Read: Query market data and account info

Avoid enabling unless explicitly needed:
- Trade: Place and cancel orders
- Transfer: Transfer between accounts
- Withdraw: Withdraw assets (often requires whitelisted IP)
