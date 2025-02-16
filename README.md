# Scripts

## 1. Deployment

forge script script/Deploy.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 2. Create Market

forge script script/CreateMarket.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 3. Create Deposit

forge script script/CreateDeposit.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 4. Create Order

forge script script/CreateOrder.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 5. Cancel Order

forge script script/CancelOrder.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

## 6. Cancel Deposit

forge script script/CancelDeposit.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Deployments

NETWORK=rise-sepolia

DATA_STORE_ADDRESS=0x236081BF0e77e9e47EF780fC6B1EAA080631C66e
ORDER_VAULT_ADDRESS=0x2Ba341c3B942b732E1Bd5CC3dDa45caF6DF4eEff
DEPOSIT_VAULT_ADDRESS=0x2551c5F09AaA0e941732EdF261AfC6f10F5E7686
ORDER_HANDLER_ADDRESS=0x7052Fa9E18C9af184B21bE69170e5480cC179D33
DEPOSIT_HANDLER_ADDRESS=0xfAC7d24c1F02290ABf6E0e68A9B4f1B0425b579a
MARKET_FACTORY_ADDRESS=0x0644e47230a8bCea4330D72a0BBc0d79aBC6Ec38
ROUTER_ADDRESS=0x582264356c7DfeACA86B18209beED5a73b027DF1

WETH_USDC_MARKET_ADDRESS=0xf5cEFc7a911f9beacF5F1AbB9b551b6f721E105D