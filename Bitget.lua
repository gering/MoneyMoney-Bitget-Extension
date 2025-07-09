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

-- Exchange rate cache
local cachedFxRates = {} -- currency pair (e.g. EUR/USD) : rate

-- Constants
local SPOT_ACCOUNT_NAME = "Bitget Spot"
local FUTURES_ACCOUNT_NAME = "Bitget Futures"

-- String extensions for XML parsing
string.parseTagContent = function(s, tag)
    return s:match("<" .. tag .. ".->(.-)</" .. tag .. ">")
end

string.parseTag = function(s, tag)
    return s:match("<" .. tag .. ".-/>")
end

string.parseTags = function(s, tag)
    return s:gmatch("<" .. tag .. ".-/>")
end

string.parseArgs = function(s)
    local args = {}
    s:gsub("([%-%w]+)=([\"'])(.-)%2", function(w, _, a)
        args[w] = a
    end)
    return args
end

-- Currency conversion functions
function fetchFxRate(base, quote)
    if quote == "EUR" then
        return 1 / fetchFxRate(quote, base)
    end

    if base == "EUR" then
        local content = Connection():request("GET", "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")
        for cube in content:parseTags("Cube") do
            local conversion = cube:parseArgs()
            if conversion.currency == quote then
                MM.printStatus("Wechselkurs geladen: " .. base .. "/" .. quote .. " @ " .. conversion.rate)
                return tonumber(conversion.rate)
            end
        end
    end

    MM.printStatus("Wechselkurs nicht verfügbar für " .. base .. "/" .. quote)
    -- Cache failed lookups to avoid repeated API calls
    setFxRate(base, quote, nil)
    return nil
end

function getFxRate(base, quote)
    if base:lower() == quote:lower() then
        return 1
    end

    -- Use cached rate
    local pair = base:upper() .. "/" .. quote:upper()
    if cachedFxRates[pair] ~= nil then
        if cachedFxRates[pair] == "not_available" then
            return 1 -- fallback to 1:1 if cached as not available
        end
        return cachedFxRates[pair]
    end

    -- Use cached rate of reversed pair
    local reversedPair = quote:upper() .. "/" .. base:upper()
    if cachedFxRates[reversedPair] ~= nil then
        if cachedFxRates[reversedPair] == "not_available" then
            return 1 -- fallback to 1:1 if cached as not available
        end
        return 1/cachedFxRates[reversedPair]
    end

    -- Fetch rate as fallback
    local rate = fetchFxRate(base, quote)
    if rate then
        setFxRate(base, quote, rate)
        return rate
    end

    return 1 -- fallback to 1:1 if no rate found
end

function convertToEUR(amount, currency)
    if currency == "EUR" then
        return amount
    elseif currency == "USDT" then
        -- Treat USDT as USD for conversion
        local rate = getFxRate("EUR", "USD")
        local eurAmount = amount / rate
        MM.printStatus("Umrechnung: " .. amount .. " " .. currency .. " = " .. eurAmount .. " EUR")
        return eurAmount
    else
        local rate = getFxRate("EUR", currency)
        local eurAmount = amount / rate
        MM.printStatus("Umrechnung: " .. amount .. " " .. currency .. " = " .. eurAmount .. " EUR")
        return eurAmount
    end
end

function getFxRateToBase(currency)
    -- Special handling for USDT - treat as USD
    if currency == "USDT" then
        return getFxRate("EUR", "USD")
    end
    return getFxRate("EUR", currency)
end

function setFxRate(base, quote, rate)
    if base ~= quote then
        local pair = base:upper() .. "/" .. quote:upper()
        if cachedFxRates[pair] == nil then
            if rate then
                MM.printStatus("Wechselkurs Cache: " .. pair .. " = " .. rate)
                cachedFxRates[pair] = rate
            else
                MM.printStatus("Wechselkurs Cache: " .. pair .. " = nicht verfügbar")
                cachedFxRates[pair] = "not_available"
            end
        end
    end
end

-- Helper functions
function fetchCurrentPrice(symbol)
    MM.printStatus("Lade aktuellen Preis für " .. symbol)
    local response = makeRequest("GET", "/api/mix/v1/market/ticker", {symbol = symbol}, nil)
    
    if response and response.code == "00000" and response.data then
        local price = tonumber(response.data.last) or tonumber(response.data.close) or 0
        MM.printStatus(string.format("Aktueller Preis für %s: %.6f", symbol, price))
        return price
    end
    
    MM.printStatus("Fehler beim Abrufen des aktuellen Preises für " .. symbol)
    return 0
end

function base64(data)
    -- Try to use MoneyMoney's base64 if available
    if MM.base64 then
        return MM.base64(data)
    end
    
    -- Fallback to custom implementation
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
            -- Get current price in USD
            local priceUSD = 0

            -- Skip price lookup for USDT itself
            if coin == "USDT" then
                priceUSD = 1
            else
                local priceResponse = makeRequest("GET", "/api/spot/v1/market/ticker", {symbol = coin .. "USDT_SPBL"}, nil)

                if priceResponse and priceResponse.code == "00000" and priceResponse.data then
                    priceUSD = tonumber(priceResponse.data.close) or 0
                end
            end

            -- Convert amount to EUR
            local amountUSD = total * priceUSD
            local amountEUR = convertToEUR(amountUSD, "USD")

            table.insert(securities, {
                name = coin .. " (Spot)",
                currency = "USD",
                market = "Bitget",
                quantity = total,
                price = priceUSD,
                currencyOfPrice = "USD",
                originalCurrencyAmount = amountUSD,
                currencyOfOriginalAmount = "USD",
                exchangeRate = getFxRateToBase("USD"),
                amount = amountEUR
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
                    
                    -- If markPrice is 0 or nil, fetch current price from ticker API
                    if markPrice == 0 then
                        markPrice = tonumber(position.lastPrice) or tonumber(position.indexPrice) or 0
                        
                        -- If still no price, fetch from ticker API
                        if markPrice == 0 then
                            markPrice = fetchCurrentPrice(position.symbol)
                            
                            -- Final fallback to avgPrice if ticker also fails
                            if markPrice == 0 then
                                markPrice = avgPrice
                            end
                        end
                    end
                    local total = tonumber(position.total) or 0
                    local margin = tonumber(position.margin) or 0

                    -- Calculate position value
                    local positionValue = total * markPrice

                    -- Extract quote currency from symbol and map to 3-digit codes
                    local quoteCurrency = "USD" -- Default (USDT -> USD for MoneyMoney)
                    local quoteCurrencyDisplay = "USDT" -- For display purposes
                    if symbol:match("USDT$") then
                        quoteCurrency = "USD"
                        quoteCurrencyDisplay = "USDT"
                    elseif symbol:match("USDC$") then
                        quoteCurrency = "USD"
                        quoteCurrencyDisplay = "USDC"
                    elseif symbol:match("BTC$") then
                        quoteCurrency = "BTC"
                        quoteCurrencyDisplay = "BTC"
                    elseif symbol:match("ETH$") then
                        quoteCurrency = "ETH"
                        quoteCurrencyDisplay = "ETH"
                    end

                    -- Format symbol with slash (e.g., AVAXUSDT -> AVAX/USDT)
                    local formattedSymbol = symbol:gsub("USDT$", "/USDT"):gsub("USDC$", "/USDC"):gsub("BTC$", "/BTC"):gsub("ETH$", "/ETH")
                    
                    -- Name without side (use quantity sign instead)
                    local name = string.format("%s %dx", formattedSymbol, leverage)
                    
                    -- Use negative quantity for short positions
                    local adjustedQuantity = total
                    if side == "Short" then
                        adjustedQuantity = -total
                    end

                    -- Convert amounts to EUR
                    local marginCurrency = position.marginCoin
                    local originalAmount = margin + unrealizedPnl
                    local amountEUR = convertToEUR(originalAmount, marginCurrency)
                    local unrealizedPnlEUR = convertToEUR(unrealizedPnl, marginCurrency)

                    -- Debug: Log the prices and raw values
                    MM.printStatus(string.format("DEBUG: %s - Kaufkurs: %.2f, Aktueller Kurs: %.2f, PnL: %.2f", formattedSymbol, avgPrice, markPrice, unrealizedPnl))
                    MM.printStatus(string.format("DEBUG RAW: markPrice='%s', avgPrice='%s'", tostring(position.markPrice), tostring(position.averageOpenPrice)))
                    MM.printStatus(string.format("DEBUG FIELDS: currency='%s', price=%.6f, purchasePrice=%.6f, originalAmount=%.2f", quoteCurrency, markPrice, avgPrice, markPrice * total))
                    
                    -- Simplified approach - let MoneyMoney handle the display
                    local positionValueUSD = markPrice * total
                    local positionValueEUR = convertToEUR(positionValueUSD, quoteCurrency)
                    
                    table.insert(securities, {
                        name = name,
                        market = "Bitget Futures",
                        quantity = adjustedQuantity,
                        originalCurrencyAmount = positionValueUSD,
                        currencyOfOriginalAmount = quoteCurrency,
                        price = markPrice,
                        currencyOfPrice = quoteCurrency,
                        purchasePrice = avgPrice,
                        currencyOfPurchasePrice = quoteCurrency,
                        exchangeRate = getFxRateToBase(quoteCurrency),
                        amount = positionValueEUR,
                        -- Use ISIN for position identifier
                        isin = string.format("%s %s %dx", formattedSymbol, side, leverage)
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

