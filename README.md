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

DATA_STORE_ADDRESS=0x94e63e917Bbc804B9FB6307c1634C0B3a2d9b6b3
ORDER_VAULT_ADDRESS=0xF32B8495032C03b4BC57cff04118575f3F6e2Bc9
DEPOSIT_VAULT_ADDRESS=0x5b1411D67aB1AB94A779ebd71fc69723A2E92C32
ORDER_HANDLER_ADDRESS=0x6Ca52789D1d025FddD66c0072bf33DcaEB894bE4
DEPOSIT_HANDLER_ADDRESS=0x8DaD84d239FBbb7FE268C12bCDAf8418408c5477
MARKET_FACTORY_ADDRESS=0x1b5d2dfAeb6f84FDD9e74540263a257f000b3bDa
ROUTER_ADDRESS=0x320923b6A3bfF8a4779bfeaCEeCf0bf8c4615976

WETH_USDC_MARKET_ADDRESS=0x74a403b336Fad0dB254d2080C28122fB739Ff558