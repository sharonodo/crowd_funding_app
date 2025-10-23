# Stacks Crowdfunding Platform

A comprehensive decentralized crowdfunding platform built on the Stacks blockchain using Clarity smart contracts.

## Overview

This platform enables users to create fundraising campaigns, contribute to projects, and participate in decentralized governance. It features advanced functionality including milestone-based funding, KYC verification, and platform governance.

## Features

### Core Functionality
- **Campaign Creation**: Create fundraising campaigns with customizable goals, durations, and categories
- **Contributions**: Contribute STX tokens to campaigns with automatic fee handling
- **Refunds**: Automatic refund system for failed campaigns
- **Withdrawals**: Secure fund withdrawal for successful campaigns

### Advanced Features
- **Milestone System**: Break campaigns into funding milestones with conditional releases
- **Campaign Extensions**: Extend campaign duration (limited extensions per campaign)
- **Batch Operations**: Contribute to multiple campaigns in a single transaction
- **Campaign Updates**: Post project updates for contributors
- **Category Management**: Organize campaigns by predefined categories

### Platform Management
- **Fee System**: Configurable platform fees (default 2.5%)
- **KYC Integration**: Know Your Customer verification for enhanced trust
- **Rate Limiting**: Anti-spam protection with per-block limits
- **Emergency Controls**: Admin pause functionality for security

### Governance System
- **Proposal Creation**: Submit governance proposals for platform changes
- **Voting Mechanism**: Weighted voting based on user's voting power
- **Proposal Execution**: Automatic execution of approved proposals
- **Fee Management**: Community-driven fee adjustments

## Smart Contract Architecture

### Constants & Limits
- Minimum goal: 1 STX (1,000,000 µSTX)
- Maximum goal: 1,000,000 STX
- Minimum duration: 1 day (144 blocks)
- Maximum duration: ~1000 days (144,000 blocks)
- Default platform fee: 2.5%

### Key Data Structures

#### Campaign Structure
```clarity
{
    title: (string-ascii 100),
    description: (string-ascii 500),
    creator: principal,
    goal: uint,
    raised: uint,
    end-block: uint,
    status: (string-ascii 20),
    category: (string-ascii 50),
    kyc-verified: bool,
    // ... additional fields
}
```

#### Milestone Structure
```clarity
{
    campaign-id: uint,
    title: (string-ascii 100),
    target-amount: uint,
    target-block: uint,
    is-reached: bool,
    funds-released: uint
}
```

## Main Functions

### Campaign Management
- `create-campaign-advanced`: Create new campaigns with full validation
- `contribute-advanced`: Make contributions with analytics tracking
- `withdraw-funds`: Withdraw funds from successful campaigns
- `claim-refund`: Claim refunds from failed campaigns

### Milestone System
- `create-milestone`: Add milestones to campaigns
- `extend-campaign`: Extend campaign duration
- `post-update`: Share campaign updates

### Governance
- `create-governance-proposal`: Submit governance proposals
- `vote-on-proposal`: Vote on active proposals
- `execute-proposal`: Execute approved proposals

### Admin Functions
- `set-platform-fee`: Adjust platform fees
- `emergency-pause`: Emergency campaign suspension
- `update-kyc-status`: Manage user KYC status

## Security Features

### Validation
- Input sanitization for titles and descriptions
- Goal and duration bounds checking
- Category validation against approved list
- Rate limiting per user per block

### Access Controls
- Owner-only administrative functions
- Creator-only campaign management
- Contributor verification for refunds
- Admin permission system

### Anti-Abuse
- Rate limiting (5 campaigns, 50 contributions per block)
- KYC verification requirements
- Emergency pause functionality
- Self-contribution prevention

## Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only access |
| u101 | Campaign not found |
| u102 | Campaign ended |
| u103 | Campaign not ended |
| u104 | Goal already reached |
| u105 | Goal not reached |
| u106 | Insufficient funds |
| u107 | Invalid amount |
| u130 | Invalid title |
| u131 | Invalid description |
| u133 | Rate limit exceeded |
| u134 | Contract paused |

## Usage Examples

### Creating a Campaign
```clarity
(contract-call? .crowdfunding create-campaign-advanced
    "My Tech Project"
    "Building the next generation blockchain app"
    u50000000  ;; 50 STX goal
    u1440      ;; 10 day duration
    "technology"
    "blockchain,innovation,defi"
)
```

### Contributing to a Campaign
```clarity
(contract-call? .crowdfunding contribute-advanced
    u1         ;; campaign ID
    u5000000   ;; 5 STX contribution
)
```

### Creating a Milestone
```clarity
(contract-call? .crowdfunding create-milestone
    u1         ;; campaign ID
    "MVP Release"
    "Complete minimum viable product"
    u25000000  ;; 25 STX target
    u720       ;; 5 day target
)
```

## Platform Statistics

The contract tracks comprehensive analytics:
- Total campaigns created
- Success/failure rates
- Total funds raised
- Category-wise statistics
- User engagement metrics

## Governance Participation

Users can participate in platform governance by:
1. Acquiring voting power (assigned by admins)
2. Creating proposals for platform improvements
3. Voting on active proposals
4. Executing approved changes

## Development Setup

1. Deploy the contract to Stacks blockchain
2. Initialize categories using `initialize-categories`
3. Set up admin permissions
4. Configure platform fees and limits
5. Enable governance (optional)

## Security Considerations

- All functions include comprehensive validation
- Emergency pause functionality for critical issues
- Rate limiting prevents spam attacks
- KYC integration for enhanced security
- Multi-level admin permission system

## Future Enhancements

- Integration with external oracles
- Cross-chain functionality
- NFT rewards for contributors
- Advanced analytics dashboard
- Mobile app integration

---