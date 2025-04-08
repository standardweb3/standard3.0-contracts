# Terminal

## Overview

The terminal is a separate CLOB (central limit order book) on top of the core protocol. It is a separate contract that is responsible for handling the logic of the order book and the interactions with the users.

Similar to Uniswap V4 hook, the developer can create their own terminal by inheriting the `Terminal` contract and implementing the `onMatch` hook.