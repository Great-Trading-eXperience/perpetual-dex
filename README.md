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

# Deployments

## Rise Testnet

ORACLE_ADDRESS=0x1c0e607b05Ca3409a3C3E38aFa122d5F84e8d8ea
DATA_STORE_ADDRESS=0xccd7b6Db041f807f93C47c9FcF93dbB9dB5AB163
ORDER_VAULT_ADDRESS=0x85386b4ebBE55024aECcfd8A5fD215a793890730
DEPOSIT_VAULT_ADDRESS=0x0F29ebbC3F40a298026CFd1d76EcCC30Ed1b897F
ORDER_HANDLER_ADDRESS=0x7814362bc8767568f5F1e2829Fc4B9ccDdC8c986
POSITION_HANDLER_ADDRESS=0x685C70bB196c59b7024FC4409194b0cFdBe4D342
MARKET_HANDLER_ADDRESS=0x84F200EBE8d5d370eb5b15cA6B6d2b4E652fdd4f
DEPOSIT_HANDLER_ADDRESS=0x08d649c08a02c2AC340111f3E39283883f9Bcf6E
MARKET_FACTORY_ADDRESS=0xeAC6F7C4180DA5b41B60FaeC194fA86Ff26636eA
ROUTER_ADDRESS=0xeB69E0A689e8a6fbdfA72b9d2882481512c783B7
WETH_USDC_MARKET_ADDRESS=0x217c52954Ef4a9F7B334333FDA22C609Ff3e62Bc

INDEXER=https://perpetual-indexer.renakaagusta.dev
