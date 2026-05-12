# Swap Contracts — Uniswap V2-Style DEX

A **decentralized exchange (DEX)** implementation in Solidity, modeled after the Uniswap V2 architecture. Provides permissionless token swapping, liquidity provision, and on-chain price discovery using the **constant-product market maker** formula (`x * y = k`).

![Solidity](https://img.shields.io/badge/Solidity-0.8.x-363636?logo=solidity)
![DEX](https://img.shields.io/badge/Type-AMM%20DEX-FF007A)
![Architecture](https://img.shields.io/badge/Pattern-Factory%20%2B%20Pair%20%2B%20Router-blueviolet)
![License](https://img.shields.io/badge/license-MIT-blue)
![Status](https://img.shields.io/badge/status-Active-success)

---

## ✨ Features

- ✅ **Constant-product AMM** (`x * y = k`) — Uniswap V2 math
- ✅ **Permissionless pair creation** — anyone can list a new token pair
- ✅ **Liquidity provision** — LPs deposit pairs and receive LP tokens
- ✅ **Swap routing** — multi-hop swaps via the Router contract
- ✅ **LP fee accrual** — swap fee goes to liquidity providers
- ✅ **Minimal & gas-optimized** — clean Solidity 0.8.x implementation
- ✅ **Audit-ready** — structured for security review

---

## 🏗️ Architecture

```
                ┌───────────────┐
                │  SwapRouter   │  ◄── User-facing entry point
                │   (Swap UX)   │     (swap, addLiquidity, removeLiquidity)
                └───────┬───────┘
                        │ uses
                        ▼
                ┌───────────────┐    deploys    ┌────────────┐
                │ SwapFactory   │ ────────────► │  SwapPair  │
                │ (Pair Registry)│              │  (per pair)│
                └───────────────┘               └────────────┘
                                                      │
                                       ┌──────────────┴──────────────┐
                                       ▼                             ▼
                                Holds reserves of            Mints/Burns LP
                                  Token A & Token B           tokens to LPs
```

### Smart Contracts

| Contract | Purpose |
|---|---|
| **`SwapFactory.sol`** | Deploys new pair contracts. Maintains a registry of every pair and ensures pair uniqueness. |
| **`SwapPair.sol`** | Core AMM contract — one per token pair. Holds reserves, executes swaps, mints/burns LP tokens. |
| **`SwapRouter.sol`** | User-facing entry point. Handles slippage protection, multi-hop swap paths, and ETH↔ERC-20 wrapping. |

---

## 📂 Project Structure

```
Swap_Contracts/
├── SwapFactory.sol     # Creates and tracks pair contracts
├── SwapPair.sol        # Per-pair AMM with reserves and LP token logic
├── SwapRouter.sol      # User-friendly swap & liquidity entry point
└── README.md
```

---

## 💡 How It Works

### The Constant-Product Formula

For every pair holding reserves of Token A (`x`) and Token B (`y`):

```
x * y = k    (constant)
```

When a user swaps `Δx` of Token A for Token B, the contract calculates the output `Δy` so that:

```
(x + Δx) * (y − Δy) = k
```

A small fee (typically 0.3%) is deducted from the input, which stays in the pool — increasing `k` over time and rewarding liquidity providers.

---

### Adding Liquidity

1. LP calls `addLiquidity(tokenA, tokenB, amountA, amountB)` on the Router
2. Router queries the Factory for the pair address (creates one if it doesn't exist)
3. Tokens are transferred into the Pair contract
4. Pair mints **LP tokens** to the provider, representing their share of the pool

### Swapping

1. User calls `swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline)` on the Router
2. Router walks the swap `path` (e.g. `[TokenA → WETH → TokenB]`)
3. Each hop transfers tokens through the corresponding Pair
4. User receives the final output token in their wallet
5. Slippage is enforced by `amountOutMin`

### Removing Liquidity

1. LP calls `removeLiquidity(tokenA, tokenB, lpAmount, ...)` on the Router
2. Router burns the LP tokens
3. LP receives a pro-rata share of both reserves (plus accumulated fees)

---

## 🚀 Getting Started

### Prerequisites

- **Node.js** ≥ 18.x
- **Hardhat** or **Foundry**
- **OpenZeppelin Contracts** (for ERC-20 interfaces)

### Installation

```bash
git clone https://github.com/amalendusuresh/Swap_Contracts.git
cd Swap_Contracts
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox @openzeppelin/contracts
```

### Compile

```bash
npx hardhat compile
```

### Deploy (Sepolia example)

```bash
npx hardhat run scripts/deploy.js --network sepolia
```

---

## 🔐 Security Considerations

- **Reentrancy protection** on state-changing functions (swap, mint, burn)
- **Slippage enforcement** via `amountOutMin` / `amountInMax` parameters on the Router
- **Deadline enforcement** prevents stale transactions from executing
- **Reserve invariant** (`k` cannot decrease) checked after every swap
- **Solidity 0.8.x** — built-in overflow/underflow protection
- **Permissionless** by design — no admin keys or upgradability surface

### Known Trade-offs

- **Constant-product only** — does not implement concentrated liquidity (V3-style)
- **No flash swap support** in current version
- **Single-hop pair logic** — multi-hop routing is handled at the Router layer
- **Standard ERC-20 only** — fee-on-transfer and rebasing tokens are not officially supported

> ⚠️ This codebase is a reference implementation and has not been formally audited. Get a professional audit before mainnet deployment with real funds.

---

## 🗺️ Roadmap

- [ ] Hardhat / Foundry test suite
- [ ] Flash swap support
- [ ] TWAP price oracle (V2-style)
- [ ] Concentrated liquidity (V3-style) — separate fork
- [ ] LP token staking (incentive farming)
- [ ] Subgraph for indexing swaps, pairs, and TVL
- [ ] Frontend (React + Ethers.js)
- [ ] Formal audit

---

## 📚 Tech Stack

- **Smart Contracts:** Solidity 0.8.x
- **Pattern:** Uniswap V2 architecture (Factory + Pair + Router)
- **Math:** Constant-product AMM (`x * y = k`)
- **Standards:** ERC-20
- **Networks:** Ethereum, BNB Chain, Polygon, any EVM-compatible chain

---

## 📖 References

This implementation is inspired by and follows the architecture of:
- [Uniswap V2 Core](https://github.com/Uniswap/v2-core)
- [Uniswap V2 Periphery](https://github.com/Uniswap/v2-periphery)
- [Uniswap V2 Whitepaper](https://uniswap.org/whitepaper.pdf)

---

## 📄 License

MIT © [Amalendu Suresh](https://github.com/amalendusuresh)

---

## 🤝 Contact

**Amalendu Suresh** — Blockchain Engineer

- 💼 **LinkedIn:** [amalendu-blockchain](https://www.linkedin.com/in/amalendu-blockchain/)
- ✍️ **Medium:** [@amalenduvishnu](https://medium.com/@amalenduvishnu)
- 📧 **Email:** amalendusuresh95@gmail.com

If you find this project useful, please ⭐ star the repo!
