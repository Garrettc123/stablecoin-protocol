# Stablecoin Protocol

A production-ready full-stack stablecoin implementation with smart contracts, backend API, and frontend dashboard.

## 🚀 Features

- **ERC-20 Compliant Stablecoin** with upgradeable proxy pattern
- **Collateral Management System** with multi-asset support
- **Price Oracle Integration** using Chainlink
- **Backend API** for transaction processing and monitoring
- **React Dashboard** for user interactions
- **Comprehensive Testing** with Hardhat
- **Multi-chain Support** (Ethereum, Polygon, BSC)

## 📁 Project Structure

```
stablecoin-protocol/
├── contracts/          # Solidity smart contracts
│   ├── StableCoin.sol
│   ├── CollateralVault.sol
│   ├── PriceOracle.sol
│   └── StabilityEngine.sol
├── backend/           # Node.js API server
│   ├── src/
│   ├── routes/
│   └── services/
├── frontend/          # React dashboard
│   ├── src/
│   └── public/
├── scripts/           # Deployment scripts
├── test/              # Contract tests
└── docs/              # Documentation
```

## 🛠️ Technology Stack

### Smart Contracts
- Solidity ^0.8.20
- OpenZeppelin Contracts
- Hardhat development environment
- Chainlink Price Feeds

### Backend
- Node.js & Express
- ethers.js v6
- MongoDB for data persistence
- WebSocket for real-time updates

### Frontend
- React 18 with TypeScript
- Wagmi & Viem for Web3 integration
- TailwindCSS for styling
- Recharts for analytics

## 📋 Prerequisites

- Node.js v18 or higher
- npm or yarn
- MetaMask wallet
- MongoDB (for backend)
- Infura/Alchemy API key

## ⚡ Quick Start

### 1. Clone the repository
```bash
git clone https://github.com/Garrettc123/stablecoin-protocol.git
cd stablecoin-protocol
```

### 2. Install dependencies
```bash
# Install contract dependencies
npm install

# Install backend dependencies
cd backend && npm install && cd ..

# Install frontend dependencies
cd frontend && npm install && cd ..
```

### 3. Set up environment variables
```bash
cp .env.example .env
# Edit .env with your configuration
```

### 4. Compile contracts
```bash
npx hardhat compile
```

### 5. Run tests
```bash
npx hardhat test
```

### 6. Deploy to testnet
```bash
npx hardhat run scripts/deploy.js --network sepolia
```

### 7. Start backend server
```bash
cd backend
npm run dev
```

### 8. Start frontend
```bash
cd frontend
npm start
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file in the root directory:

```env
# Network Configuration
INFURA_API_KEY=your_infura_key
ALCHEMY_API_KEY=your_alchemy_key
PRIVATE_KEY=your_private_key

# Contract Addresses (after deployment)
STABLECOIN_ADDRESS=
VAULT_ADDRESS=
ORACLE_ADDRESS=

# Backend Configuration
MONGODB_URI=mongodb://localhost:27017/stablecoin
PORT=3001
JWT_SECRET=your_jwt_secret

# Frontend Configuration
REACT_APP_API_URL=http://localhost:3001
REACT_APP_CHAIN_ID=11155111
```

## 📊 Architecture

### Smart Contract Layer

1. **StableCoin.sol**: Main ERC-20 token with mint/burn capabilities
2. **CollateralVault.sol**: Manages deposited collateral and reserve ratios
3. **PriceOracle.sol**: Integrates Chainlink for USD price feeds
4. **StabilityEngine.sol**: Automated minting/burning logic and liquidations
5. **Governance.sol**: Protocol parameter management

### Backend API

- RESTful API endpoints for all operations
- WebSocket connections for real-time price updates
- Event listeners for blockchain transactions
- Database for user accounts and transaction history

### Frontend Dashboard

- Connect wallet and manage account
- Mint/burn stablecoins
- View collateral positions
- Monitor reserve ratios
- Transaction history
- Analytics and charts

## 🧪 Testing

```bash
# Run all tests
npx hardhat test

# Run with coverage
npx hardhat coverage

# Run specific test
npx hardhat test test/StableCoin.test.js

# Test on local node
npx hardhat node
# In another terminal:
npx hardhat run scripts/deploy.js --network localhost
```

## 🚀 Deployment

### Testnet Deployment (Sepolia)

```bash
# Deploy all contracts
npx hardhat run scripts/deploy-full.js --network sepolia

# Verify on Etherscan
npx hardhat verify --network sepolia DEPLOYED_CONTRACT_ADDRESS
```

### Mainnet Deployment

⚠️ **WARNING**: Deploying to mainnet requires:
- Complete security audits
- Legal compliance review
- Sufficient ETH for gas fees
- Multi-sig wallet setup

```bash
# Deploy to mainnet
npx hardhat run scripts/deploy-full.js --network mainnet

# Verify contracts
npx hardhat verify --network mainnet DEPLOYED_CONTRACT_ADDRESS
```

## 🔐 Security Considerations

- **Smart Contract Audits**: Get professional audits before mainnet
- **Multi-signature Wallets**: Use for admin functions
- **Time Locks**: Implement for critical parameter changes
- **Emergency Pause**: Circuit breaker for crisis situations
- **Rate Limiting**: Prevent flash loan attacks
- **Oracle Redundancy**: Multiple price feed sources

## 📈 Monitoring

### On-Chain Metrics
- Total supply
- Collateralization ratio
- Reserve balances
- Oracle price feeds
- Liquidation events

### Backend Metrics
- API response times
- Transaction success rates
- Active user count
- System health checks

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

MIT License - see LICENSE file for details

## ⚠️ Disclaimer

This software is provided as-is for educational and development purposes. Deploying a stablecoin to mainnet requires:
- Professional security audits
- Legal compliance review
- Regulatory approval
- Adequate risk management
- Insurance and reserves

The authors assume no liability for any losses incurred through use of this software.

## 📞 Support

- GitHub Issues: Report bugs or request features
- Documentation: See `/docs` folder
- Discord: [Join our community]

## 🗺️ Roadmap

- [x] Core ERC-20 implementation
- [x] Collateral management system
- [x] Backend API
- [x] Frontend dashboard
- [ ] Multi-collateral support
- [ ] Cross-chain bridges
- [ ] Mobile app
- [ ] Governance token
- [ ] DAO implementation
- [ ] Advanced stability mechanisms

---

**Built by Garrett Carroll** | [GitHub](https://github.com/Garrettc123) | AI Enterprise System Founder