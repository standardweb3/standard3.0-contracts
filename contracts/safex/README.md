# Safex

Decentralized orderbook exchange contracts

1) Provide clear documentation about which contracts are upgradable and/or use proxy patterns, 2) use initialization functions for upgradeable contracts instead of constructors and do not initialize state variables as explained in OpenZeppelin docs, 3) use disableInitializers() in constructors.


## Upgradeable contracts

MatchingEngine.sol: MatchingEngine entry point contract can be updated for integrations on stablecoin, future market, and lending protocols.

## Proxy Contracts

MatchingEngine.sol: MatchingEngine entry point contract can be updated for integrations on stablecoin, future market, and lending protocols.

Orderbook.sol: Orderbook.sol contract is a proxy pattern contract for improving orderbook storage and order matching priority sorting algorithms.


## Licensing

The primary license for the codes in this repo are the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE). 
