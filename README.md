# 🏥 Clinica - Clinical Trial Data Verifier

A blockchain-based system for recording and verifying clinical trial data, ensuring data integrity and transparency through immutable smart contracts.

## 🎯 Overview

Clinica provides a decentralized solution for clinical trial data management, leveraging the Stacks blockchain to guarantee data immutability, transparency, and verifiable integrity throughout the research process.

## ✨ Features

- 📊 **Trial Management**: Create and manage clinical trials with timeline tracking
- 👥 **Patient Registration**: Secure patient enrollment with unique identifiers
- 🔒 **Data Recording**: Immutable data entry with cryptographic hashing
- ✅ **Data Verification**: Multi-party verification system for data integrity
- 🔐 **Access Control**: Role-based permissions for trial participants
- 📈 **Audit Trail**: Complete transparency with blockchain-based logging
- ⏱️ **Timeline Management**: Block-based duration and progress tracking

## 🚀 Quick Start

### Prerequisites
- Clarinet CLI installed
- Stacks wallet for testing

### Deployment
```bash
clarinet console
```

## 📋 Usage Instructions

### 1. Creating a Clinical Trial
```clarity
(contract-call? .Clinica create-trial 
    "COVID-19 Vaccine Efficacy Study" 
    "Johns Hopkins University" 
    u52560) ;; ~1 year in blocks
```

### 2. Granting Permissions
```clarity
(contract-call? .Clinica grant-permission 
    u1 
    'SP2EXAMPLE...
    "researcher")
```

### 3. Registering Patients
```clarity
(contract-call? .Clinica register-patient 
    u1 
    "PATIENT-001-ANONYMIZED")
```

### 4. Recording Patient Data
```clarity
(contract-call? .Clinica record-patient-data 
    u1 
    "blood-work" 
    0x1234567890abcdef...)
```

### 5. Verifying Data
```clarity
(contract-call? .Clinica verify-data 
    u1 
    0x987654321fedcba... 
    "Independent verification completed")
```

## 🔍 Read-Only Functions

### Trial Information
- `get-trial` - Retrieve trial details
- `get-trial-stats` - Get trial statistics
- `get-trial-timeline` - View progress and timeline
- `get-audit-trail` - Access complete audit history

### Patient Information  
- `get-patient` - Retrieve patient details
- `get-patient-summary` - Get patient overview
- `get-patient-data` - Access recorded data

### Data Verification
- `verify-data-integrity` - Check data hash consistency
- `get-data-verification` - View verification details
- `get-unverified-data` - List pending verifications

## 🛡️ Security Features

- **Immutable Records**: All data permanently stored on blockchain
- **Cryptographic Hashing**: Data integrity protection
- **Role-Based Access**: Granular permission system
- **Multi-Party Verification**: Independent data validation
- **Emergency Controls**: Trial pause functionality

## 🔧 Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Resource not found |
| u102 | Unauthorized access |
| u103 | Invalid data provided |
| u104 | Trial already exists |
| u105 | Trial not active |
| u106 | Patient already exists |
| u107 | Invalid status transition |

## 🏗️ Architecture

The contract uses five main data structures:
- **Trials**: Core trial information and metadata
- **Trial Permissions**: Role-based access control
- **Patients**: Patient enrollment and status tracking  
- **Patient Data**: Recorded clinical data entries
- **Data Verification**: Independent verification records

## 🧪 Testing

Run the test suite:
```bash
clarinet test
```

Check contract syntax:
```bash
clarinet check
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch
3. Run `clarinet check` to verify syntax
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🔗 Links

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarinet Documentation](https://docs.hiro.so/clarinet/)
- [Clarity Language Reference](https://docs.stacks.co/docs/clarity/)
