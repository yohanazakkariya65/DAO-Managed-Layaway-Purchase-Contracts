# 🏪 DAO-Managed Layaway Purchase Contracts

A Clarity smart contract system that enables **layaway purchases** where buyers pay in installments while the DAO securely holds goods/NFTs until full payment completion.

## 🌟 Features

- 📅 **Flexible Payment Schedules** - Set custom installment plans
- 🔒 **DAO-Managed Escrow** - Secure holding of items until payment completion  
- 💰 **Automated Fee Collection** - DAO treasury fees on transactions
- ⚡ **Default Handling** - Automatic contract resolution for overdue payments
- 📊 **Contract Tracking** - View all buyer/seller contract history

## 🚀 How It Works

1. **Create Contract** - Buyer creates layaway agreement with seller
2. **DAO Holds Item** - Seller deposits item with DAO for escrow
3. **Make Payments** - Buyer pays installments according to schedule
4. **Release Item** - DAO releases item to buyer upon full payment

## 📋 Contract Functions

### Public Functions

#### `create-layaway-contract`
```clarity
(create-layaway-contract seller item-id total-price installments payment-schedule)
```
Create a new layaway purchase contract.

#### `make-payment`
```clarity
(make-payment contract-id amount)
```
Make an installment payment towards your layaway contract.

#### `dao-hold-item`
```clarity
(dao-hold-item contract-id)
```
Seller deposits item with DAO for secure holding.

#### `release-item`
```clarity
(release-item contract-id)
```
Release item to buyer after full payment completion.

#### `cancel-contract`
```clarity
(cancel-contract contract-id)
```
Cancel active contract (refunds buyer if payments made).

#### `handle-default`
```clarity
(handle-default contract-id)
```
Handle overdue contracts (transfers payments to seller).

### Read-Only Functions

#### `get-contract`
```clarity
(get-contract contract-id)
```
Retrieve contract details by ID.

#### `get-buyer-contracts` / `get-seller-contracts`
```clarity
(get-buyer-contracts buyer-principal)
(get-seller-contracts seller-principal)
```
Get all contracts for a specific buyer or seller.

## 🛠️ Usage Example

```clarity
;; 1. Create layaway contract
(contract-call? .layaway create-layaway-contract 
    'SP2..SELLER 
    u1              ;; item-id
    u1000000        ;; 10 STX total price
    u4              ;; 4 installments  
    u144)           ;; 144 blocks between payments

;; 2. Seller holds item with DAO
(contract-call? .layaway dao-hold-item u1)

;; 3. Make installment payment
(contract-call? .layaway make-payment u1 u250000) ;; 2.5 STX

;; 4. After full payment, release item
(contract-call? .layaway release-item u1)
```

## ⚙️ Configuration

- **DAO Treasury**: Configurable treasury address for fee collection
- **DAO Fee Rate**: Default 2.5% fee (250 basis points) on payments
- **Contract Limits**: Max 50 contracts per buyer/seller

## 🔐 Security Features

- ✅ **Authorization Checks** - Only contract parties can perform actions
- ✅ **Payment Validation** - Ensures proper installment amounts
- ✅ **Deadline Enforcement** - Automatic default handling
- ✅ **Escrow Protection** - DAO holds items securely

## 📦 Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- Node.js for testing

### Testing
```bash
clarinet test
```

### Deployment
```bash
clarinet deploy
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License.

---

*Built with ❤️ using Clarity smart contracts on Stacks blockchain*
