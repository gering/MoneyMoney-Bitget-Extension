-- Inofficial Bitget Extension (www.bitget.com) for MoneyMoney
-- Fetches Spot balances and Futures positions via Bitget API
-- Returns them as securities
--
-- Username: API Key
-- Password: API Secret:Passphrase (format: "your-api-secret:your-passphrase")
--
-- MIT License

-- Copyright (c) 2025 Robert Gering

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

WebBanking{
    version = 1.0,
    country = "de",
    description = string.format(MM.localizeText("Fetch balances and positions from %s"), "Bitget"),
    services = {"Bitget"},
}

-- State
local connection
local apiKey
local apiSecret
local passphrase
local baseUrl = "https://api.bitget.com"

-- Constants
local SPOT_ACCOUNT_NAME = "Bitget Spot"
local FUTURES_ACCOUNT_NAME = "Bitget Futures"

-- Helper functions
function base64(data)
    local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function createSignature(timestamp, method, requestPath, queryString, body)
    local message = timestamp .. method .. requestPath
    if queryString and queryString ~= "" then
        message = message .. "?" .. queryString
    end
    if body and body ~= "" then
        message = message .. body
    end

    local signature = MM.hmac256(apiSecret, message)
    return base64(signature)
end

function makeRequest(method, path, queryParams, body)
    local timestamp = tostring(os.time() * 1000)
    local queryString = ""

    if queryParams then
        local params = {}
        for k, v in pairs(queryParams) do
            table.insert(params, k .. "=" .. v)
        end
        queryString = table.concat(params, "&")
        if queryString ~= "" then
            path = path .. "?" .. queryString
        end
    end

    local signature = createSignature(timestamp, method, path:match("^([^?]+)"), queryString, body or "")

    local headers = {
        ["ACCESS-KEY"] = apiKey,
        ["ACCESS-SIGN"] = signature,
        ["ACCESS-TIMESTAMP"] = timestamp,
        ["ACCESS-PASSPHRASE"] = passphrase,
        ["Content-Type"] = "application/json"
    }

    local content = connection:request(method, baseUrl .. path, body, nil, headers)

    if content then
        local json = JSON(content)
        return json:dictionary()
    end

    return nil
end

-- MoneyMoney API implementation
function SupportsBank(protocol, bankCode)
    return protocol == ProtocolWebBanking and bankCode == "Bitget"
end

function InitializeSession(protocol, bankCode, username, username2, password, username3)
    MM.printStatus("Initialisiere Bitget-Verbindung")

    apiKey = username

    -- Parse API Secret and Passphrase from password field (format: "secret:passphrase")
    local passwordParts = {}
    for part in password:gmatch("([^:]+)") do
        table.insert(passwordParts, part)
    end

    if #passwordParts ~= 2 then
        MM.printStatus("Fehler: Passwort muss Format 'API-Secret:Passphrase' haben")
        return LoginFailed
    end

    apiSecret = passwordParts[1]
    passphrase = passwordParts[2]

    if not apiKey or apiKey == "" then
        MM.printStatus("Fehler: API Key fehlt")
        return LoginFailed
    end

    if not apiSecret or apiSecret == "" then
        MM.printStatus("Fehler: API Secret fehlt")
        return LoginFailed
    end

    if not passphrase or passphrase == "" then
        MM.printStatus("Fehler: Passphrase fehlt")
        return LoginFailed
    end

    connection = Connection()

    -- Test connection with a simple API call
    local response = makeRequest("GET", "/api/spot/v1/public/time", nil, nil)

    if not response or response.code ~= "00000" then
        MM.printStatus("Fehler: Verbindung fehlgeschlagen")
        return LoginFailed
    end

    MM.printStatus("Verbindung erfolgreich")
end

function ListAccounts(knownAccounts)
    local accounts = {}

    -- Spot Account
    table.insert(accounts, {
        name = SPOT_ACCOUNT_NAME,
        owner = apiKey:sub(1, 8) .. "...",
        accountNumber = "SPOT",
        currency = "EUR",
        type = AccountTypePortfolio,
        portfolio = true
    })

    -- Futures Account
    table.insert(accounts, {
        name = FUTURES_ACCOUNT_NAME,
        owner = apiKey:sub(1, 8) .. "...",
        accountNumber = "FUTURES",
        currency = "EUR",
        type = AccountTypePortfolio,
        portfolio = true
    })

    return accounts
end

function RefreshAccount(account, since)
    local securities = {}

    if account.accountNumber == "SPOT" then
        MM.printStatus("Lade Spot-Guthaben...")
        securities = fetchSpotBalances()
    elseif account.accountNumber == "FUTURES" then
        MM.printStatus("Lade Futures-Positionen...")
        securities = fetchFuturesPositions()
    end

    return {securities = securities}
end

function fetchSpotBalances()
    local securities = {}

    local response = makeRequest("GET", "/api/spot/v1/account/assets", nil, nil)

    if not response or response.code ~= "00000" then
        MM.printStatus("Fehler beim Abrufen der Spot-Guthaben")
        return securities
    end

    for _, asset in ipairs(response.data or {}) do
        local coin = asset.coinName or asset.coin
        if not coin then
            -- Skip asset if no coin name available
            MM.printStatus("Überspringe Asset ohne Coin-Name")
            goto continue
        end

        local available = tonumber(asset.available) or 0
        local frozen = tonumber(asset.frozen) or 0
        local locked = tonumber(asset.locked) or 0
        local total = available + frozen + locked

        if total > 0 then
            -- Get current price
            local price = 0

            -- Skip price lookup for USDT itself
            if coin == "USDT" then
                price = 1
            else
                local priceResponse = makeRequest("GET", "/api/spot/v1/market/ticker", {symbol = coin .. "USDT_SPBL"}, nil)

                if priceResponse and priceResponse.code == "00000" and priceResponse.data then
                    price = tonumber(priceResponse.data.close) or 0
                end
            end

            table.insert(securities, {
                name = coin .. " (Spot)",
                currency = "USD",
                market = "Bitget",
                quantity = total,
                price = price,
                amount = total * price
            })
        end
        ::continue::
    end

    MM.printStatus("Spot-Guthaben geladen")
    return securities
end

function fetchFuturesPositions()
    local securities = {}

    -- Fetch all futures positions
    local productTypes = {"umcbl", "dmcbl", "cmcbl"} -- USDT, Universal, USDC perpetuals

    for _, productType in ipairs(productTypes) do
        local response = makeRequest("GET", "/api/mix/v1/position/allPosition-v2", {productType = productType}, nil)

        if response and response.code == "00000" and response.data then
            for _, position in ipairs(response.data or {}) do
                if tonumber(position.total) and tonumber(position.total) > 0 then
                    local symbol = position.symbol:gsub("_.*", "") -- Remove suffix like _UMCBL
                    local side = position.holdSide == "long" and "Long" or "Short"
                    local leverage = tonumber(position.leverage) or 1
                    local unrealizedPnl = tonumber(position.unrealizedPL) or 0
                    local markPrice = tonumber(position.markPrice) or 0
                    local avgPrice = tonumber(position.averageOpenPrice) or 0
                    local total = tonumber(position.total) or 0
                    local margin = tonumber(position.margin) or 0

                    -- Calculate position value
                    local positionValue = total * markPrice

                    -- Format symbol with slash (e.g., AVAXUSDT -> AVAX/USDT)
                    local formattedSymbol = symbol:gsub("USDT$", "/USDT"):gsub("USDC$", "/USDC"):gsub("BTC$", "/BTC"):gsub("ETH$", "/ETH")
                    
                    -- Name includes symbol, side and leverage
                    local name = string.format("%s %s %dx", formattedSymbol, side, leverage)

                    -- For display, we show the margin + unrealized PnL as the amount
                    local amount = margin + unrealizedPnl

                    table.insert(securities, {
                        name = name,
                        currency = position.marginCoin,
                        market = "Bitget Futures",
                        quantity = total,
                        price = markPrice,
                        amount = amount,
                        -- Additional info in ISIN field for visibility
                        isin = string.format("PnL: %.2f %s", unrealizedPnl, position.marginCoin)
                    })
                end
            end
        end
    end

    MM.printStatus("Futures-Positionen geladen")
    return securities
end

function EndSession()
    -- Nothing to do
end

