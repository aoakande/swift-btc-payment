# SwiftBTC

**Lightning-fast merchant payments with Bitcoin security**

SwiftBTC is a decentralized payment processor built on the Stacks blockchain that enables merchants to accept sBTC payments with sub-10 second settlement and Bitcoin-level security.

## 🚀 Core Features

- **Sub-10s Settlement** - Faster than traditional crypto payments
- **Bitcoin Security** - Full Bitcoin network security via Stacks
- **Merchant-Friendly** - Simple integration with clear fee structure  
- **sBTC Native** - Purpose-built for sBTC ecosystem growth

## 📋 Development Phases

### Phase 1: Core Infrastructure ✅
- ✅ Payment processor smart contract in Clarity
- ✅ Merchant registry and verification system
- ✅ Basic payment creation and processing flow
- ✅ Settlement system with platform fees

### Phase 2: Merchant Tools (In Progress)
- [ ] Merchant dashboard interface
- [ ] Payment link generation
- [ ] Transaction monitoring system
- [ ] Webhook integration

### Phase 3: Integration & SDK (Planned)
- [ ] JavaScript SDK for merchants
- [ ] Payment widget components
- [ ] API documentation
- [ ] Security audits

## 🏗️ Project Structure

```
swift-btc-payments/
├── contracts/
│   ├── payment-processor.clar    # Core payment processing
│   └── merchant-registry.clar    # Merchant management
├── frontend/                     # Merchant dashboard (coming soon)
├── backend/                      # API services (coming soon)
├── sdk/                          # Integration tools (coming soon)
└── docs/                         # Documentation
```

## 🔧 Smart Contracts

### Payment Processor (`payment-processor.clar`)
Handles payment creation, processing, and settlement with automatic fee calculation.

**Key Functions:**
- `create-payment` - Merchants create payment requests
- `process-payment` - Payers confirm payments (sub-10s)
- `settle-payment` - Automatic settlement to merchants
- `withdraw-balance` - Merchant fund withdrawals

### Merchant Registry (`merchant-registry.clar`)
Manages merchant profiles, verification, and tier-based benefits.

**Key Functions:**
- `register-merchant` - Merchant onboarding with STX staking
- `update-merchant-settings` - Payment preferences configuration
- `upgrade-tier` - Tier advancement through additional staking
- `request-verification` - KYB verification workflow

## 💰 Merchant Tiers

| Tier | Stake Required | Benefits |
|------|----------------|----------|
| **Basic** | 1 STX | Basic payment processing |
| **Premium** | 10 STX | Lower fees, priority support |
| **Enterprise** | 50 STX | Custom features, dedicated support |

## 🎯 Built for Stacks Code4STX

SwiftBTC leverages Stacks' unique capabilities:
- **sBTC Integration** - Native Bitcoin-backed payments
- **Clarity Smart Contracts** - Secure, predictable contract execution
- **Bitcoin Settlement** - Transactions settled to Bitcoin blockchain
- **Block-time Optimization** - Sub-10s confirmation using Stacks speed

## 🚦 Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js 16+ (for future frontend development)
- Stacks wallet for testing

### Local Development
```bash
# Clone repository
git clone https://github.com/aoakande/swift-btc-payments.git
cd swift-btc-payments

# Check contracts
clarinet check

# Run tests (coming soon)
clarinet test
```

## 📈 Roadmap

- [x] **Q1 2025** - Core smart contracts
- [ ] **Q2 2025** - Merchant dashboard and SDK
- [ ] **Q3 2025** - Mobile integration and plugins
- [ ] **Q4 2025** - Enterprise features and scaling

## 🤝 Contributing

SwiftBTC is built for the Stacks ecosystem. Contributions welcome!

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Stacks Explorer** - [View Contracts](https://explorer.stacks.co/)
- **sBTC Documentation** - [Learn More](https://stacks.org/sbtc)
- **Code4STX Program** - [Participate](https://stacks.org/code-for-stx)

---

**Built with ❤️ for the Stacks ecosystem**
