# 🛡 SentinelSwap

**SentinelSwap** is a Solidity smart contract that acts as a secure wrapper around a Uniswap V2-like Router. It introduces token whitelisting, timelocked liquidity, and reward accrual for liquidity providers, without needing to create custom liquidity pools.

---

## 📚 Overview

This contract:

* Wraps `addLiquidity` and `removeLiquidity` of Uniswap V2 Routers
* Tracks liquidity added per user
* Locks liquidity for a minimum period
* Accrues rewards over time based on the user's liquidity
* Supports only whitelisted tokens for enhanced security

---

## ✨ Features

### ✅ Token Whitelisting

Only explicitly allowed tokens can be used for liquidity operations.

### 💧 Add Liquidity

* Transfers desired amounts from user
* Approves router
* Calls `addLiquidity`
* Refunds leftovers to user
* Updates user's liquidity and reward state

### 🔓 Remove Liquidity

* Validates timelock has passed
* Checks that the pair exists via the Factory
* Transfers LP tokens from user and approves router
* Calls `removeLiquidity`
* Updates liquidity and rewards

### 🪙 Reward Accrual

* Reward rate: `0.01` tokens per second per LP token (`1e16 wei`)
* Rewards accumulate over time and can be claimed
* Reward emission is tracked and emitted as an event (`RewardClaimed`)

### ⏳ Timelock Mechanism

* Liquidity cannot be withdrawn before 1 day has passed since adding it

---

## 🧪 Test Coverage

Test suite: `SentinelSwapTest.t.sol`

### ✅ Passed Tests (11/11)

* `testAddLiquidityRefundsLeftoversAndMintsLP`
* `testAddLiquidityRevertsOnDeadline`
* `testAddLiquidityRevertsOnNotAllowedToken`
* `testRemoveLiquidityRevertsBeforeTimelock`
* `testRemoveLiquidityRevertsIfLocked`
* `testRemoveLiquidityRevertsIfPairDoesNotExist`
* `testRemoveLiquidityRefundsTokens`
* `testClaimRewardsAccumulatesOverTime`
* `testClaimRewardsEmitsEvent`
* `testClaimRewardsRevertsIfZero`
* `testUpdateRewardsNoLiquidityDoesNotRevert`

### 🔍 Forge Coverage

```
src/SentinelSwap.sol      | 100.00% lines | 95.71% statements | 76.92% branches | 100.00% funcs
src/mocks/MockFactory.sol | 100.00% lines | 100.00% statements | 100.00% branches | 100.00% funcs
src/mocks/MockLP.sol      | 100.00% lines | 100.00% statements | 50.00% branches | 100.00% funcs
src/mocks/MockRouter.sol  | 100.00% lines | 100.00% statements | 50.00% branches | 100.00% funcs
src/mocks/TestToken.sol   | 100.00% lines | 100.00% statements | n/a             | 100.00% funcs
```

### ✅ Total:

* **Lines**: 100.00% (`90/90`)
* **Statements**: 96.77% (`90/93`)
* **Branches**: 72.22% (`13/18`)
* **Functions**: 100.00% (`18/18`)

---

## 🔐 Security Considerations

* Enforced whitelisting prevents malicious token usage
* Timelocks prevent flash liquidity exploits
* Reward emission logic uses state tracking to avoid manipulation

---

## 🧰 Tech Stack

* **Solidity 0.8.28**
* **Forge (Foundry)** for testing & coverage
* **OpenZeppelin**: Ownable, SafeERC20

---

## 👨‍🔬 Developer Notes

* Reward logic is extensible to include real token payouts in future
* Custom errors used for optimized gas and clarity
* Designed for compatibility with Uniswap V2-style DEXs

---

## 🧪 Run Tests

```bash
forge test -vv
```

## 📊 Run Coverage

```bash
forge coverage
```
