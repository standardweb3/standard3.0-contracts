# SABT
Contracts for dividing revenue from running a dapp with its Standard Account Bound Token.

## Membership
The membership contract mints membership with UID engraved in NFT. NFT is ERC1155. Membership controls users' status and allows them to exchange points they collect for a share of the 40% revenue allocated to dex users with membership.

## Block/Time Accountant
The accountant contract stores how many tokens have been collected in an era (blocks in 1 month / 1 month in block). It is for recording progress only, and it does not store any funds or crypto.

## Treasury
The treasury contract stores funds and is the venue where investors, developers, and users collect profit from the 60% revenue allocated to them.

## SABT
The SABT contract mints and burns NFT which proves a user's identity from holding wallet.

## Licensing

The primary license for the codes in this repo are the Business Source License 1.1 (`BUSL-1.1`), see [`LICENSE`](./LICENSE). 
