# 🔄 Sentinel Swap

**Sentinel Swap** is a simplified Uniswap V2-style orchestrator contract built with Solidity and Foundry. It enables token swaps and liquidity operations using an external router (e.g. Uniswap V2-compatible), and introduces basic liquidity mining and timelock features to enhance safety and incentivization.

> **Note**
> This contract integrates liquidity rewards and enforces withdrawal restrictions to improve protocol robustness.

---

## 🔹 Key Features

* ✅ Add/remove liquidity using Uniswap V2 router.
* ✅ Enforce 1-day **liquidity timelock** before withdrawal.
* ✅ Track **liquidity mining rewards** per user.
* ✅ Function to **claim accumulated rewards** (`claimRewards`).
* ✅ Secure token whitelist with custom errors.
* ✅ Deployment and testing via Foundry.

---

## 📄 Contract Overview

| 🔧 Item                  | 📋 Description                                           |
| ------------------------ | -------------------------------------------------------- |
| **Contract Name**        | `SentinelSwap`                                           |
| **Liquidity Timelock**   | `1 days` (configurable)                                  |
| **Reward Rate**          | `1e16` per second per LP token (can be updated manually) |
| **Tokens Tracked**       | Liquidity Providers and rewards per user                 |
| **Router Compatibility** | Uniswap V2-style router and LP contracts                 |

---

## 🚀 How to Use Locally

### 1️⃣ Clone and Set Up

```bash
git clone https://github.com/Sulvank/sentinel-swap.git
cd sentinel-swap
```

### 2️⃣ Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 3️⃣ Run Tests

```bash
forge test -vvv
```

> You can use `forge coverage` to generate a full test coverage report.

---

## 🧠 Project Structure

```
sentinel-swap/
├── lib/                        # OpenZeppelin + other libraries
├── script/                    # (Optional) Deployment scripts
├── src/                       # Main smart contracts
│   ├── SentinelSwap.sol       # Core contract
│   ├── mocks/                 # Mocks for testing (router, factory, LP)
├── test/                      # Foundry tests
│   └── SentinelSwap.t.sol     # Complete test suite
├── foundry.toml               # Foundry configuration
└── README.md                  # Project documentation
```

---

## 🔍 Contract Summary

### Functions

| Function                          | Description                                           |
| --------------------------------- | ----------------------------------------------------- |
| `addLiquidity(...)`               | Provides liquidity via external router                |
| `removeLiquidity(...)`            | Withdraws liquidity with timelock enforcement         |
| `claimRewards()`                  | Allows users to claim their accrued liquidity rewards |
| `setAllowedToken(token, allowed)` | Owner function to whitelist or block a token          |

### Events

| Event                 | Description                                   |
| --------------------- | --------------------------------------------- |
| `LiquidityAdded(...)` | Emitted on each successful liquidity addition |
| `RewardClaimed(...)`  | Emitted when user claims reward tokens        |

### Custom Errors

| Error                  | When it triggers             |
| ---------------------- | ---------------------------- |
| `DeadlineExpired(...)` | Provided deadline has passed |
| `TokenNotAllowed(...)` | Token is not whitelisted     |
| `ZeroAddress()`        | Passed address is invalid    |

---

## 🧪 Tests

Includes comprehensive test coverage for:

* ✅ Liquidity addition and leftovers refund
* ✅ Liquidity withdrawal with timelock enforcement
* ✅ Reward accumulation and claiming
* ✅ Reverts on deadline and unapproved tokens
* ✅ Event emission (`LiquidityAdded`, `RewardClaimed`)

### 📊 Test Coverage

| File                      | % Lines  | % Statements | % Branches | % Functions |
| ------------------------- | -------- | ------------ | ---------- | ----------- |
| `src/SentinelSwap.sol`    | 100%     | 100%         | 100%       | 100%        |
| `test/SentinelSwap.t.sol` | 100%     | 100%         | 100%       | 100%        |
| **Total**                 | **100%** | **100%**     | **100%**   | **100%**    |

> Generated using `forge coverage` with Solidity 0.8.28

---

## 📜 License

This project is licensed under the MIT License. See the `LICENSE` file for details.

---

### 🛡️ Sentinel Swap: Extendable, Secure, Reward-Based Liquidity Layer
