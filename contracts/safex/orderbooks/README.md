# Orderbook Contracts

Orderbook contracts for SafeX orderbook dex.

# Remediation

## hacken-2023-05-18-C01 

Calculations were invalid because token decimals are intended to make overflows. the decimal is 32 in test input, unlike 18 for regular ERC20. However, lowering decimals does not make underflow, and it is trivial when it comes to small number calculations, so check logic on pair creation is changed to check decimal is less than or equal to 18.