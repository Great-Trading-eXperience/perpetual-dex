# Overview

The GTX Perp Dex is a revolutionary decentralized exchange for perpetual futures trading that emphasizes true decentralization and permissionless access.

# Deployed Contracts
- **Router**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4
- **Market Factory**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4
- **Curator Factory**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4
- **Curator Vault Factory**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4
- **Order Vault**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4
- **Order Handler**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4
- **Position Handler**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4
- **Deposit Handler**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4
- **Withdraw Handler**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4
- **Market Handler**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4
- **Data Store**: 0x777f7b7f1757ee06128e4840d7b503a75a7a06b4

# Key Features
- **Fully permissionless token listing**: Anyone can deploy and list their own tokens for perpetual futures trading without requiring approval
- **Decentralized execution**: The protocol is powered by a permissionless keeper network where anyone can become a keeper to execute orders and earn execution fees
- **Innovative price oracle**: Mark prices are secured through AVS (Actively Validated Service) and zkTLS technology, ensuring reliable and manipulation-resistant price feeds while maintaining decentralization
- **Curator Vaults**: Curator Vaults are a new way to manage and grow your crypto portfolio. They are a collection of vaults that are managed by a curator. The curator is a trusted entity that is responsible for managing the vaults and maintaining risk parameters to ensure the safety of user funds through careful monitoring and adjustment.

# Scripts

## 1. Deploy Tokens

forge script script/DeployTokens.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 1. Deploy Core

forge script script/DeployCore.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# 2. Add Tokens to Oracle

forge script script/AddTokensToOracle.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# 3. Set initial prices

forge script script/UpdateTokensPriceOnOracle.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 4. Create Market

forge script script/CreateMarket.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 5. Create Deposit

forge script script/CreateDeposit.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 6. Execute Deposit

forge script script/ExecuteDeposit.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 7. Create Order

forge script script/CreateOrder.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 8. Execute Order

forge script script/ExecuteOrder.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 9. Liquidate Position

forge script script/LiquidatePosition.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 10. Cancel Order

forge script script/CancelOrder.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 10. Cancel Deposit

forge script script/CancelDeposit.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 11. Create Withdraw

forge script script/CreateWithdraw.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 12. Execute Withdraw

forge script script/ExecuteWithdraw.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 13. Cancel Withdraw

forge script script/CancelWithdraw.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 14. Deploy Curator

forge script script/DeployCurator.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 15. Deposit to Curator Vaults

forge script script/DepositToCuratorVaults.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast