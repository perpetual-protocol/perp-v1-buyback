# Perp v1 Buyback

This repository contains the code for the Perpetual Protocol v1 buyback program.

## Overview
Use 17.5% monthly treasury fee income to buy back PERP over the years to cover all op4>op2 users, for their op4-op2 amount. ($3.59M), pro rata to compensation amount.

- [Forum](https://gov.perp.fi/t/modified-perp-buyback-proposal-to-support-affected-v1-users/920)
- [Snapshot](https://snapshot.org/#/vote-perp.eth/proposal/0x82eeed00c3912f2537c3479e365da207a4e9e3d92fcab265a0cab1148af25d28)

## Local Development
```bash
git clone git@github.com:perpetual-protocol/perp-v1-buyback.git

// Install
npm install

// Build
npm run build

// Run test
npm run test

// Deploy to optimism-goerli
npm run deploy:optimism-goerli

// Deploy to optimism
npm run deploy:optimism
```