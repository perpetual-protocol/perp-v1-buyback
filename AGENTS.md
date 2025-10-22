# Repository Guidelines

Use this guide to align updates with the Perp v1 Buyback workflow and keep reviews fast.

## Project Structure & Module Organization
- `src/` holds upgradeable contracts; subfolders `interface/` and `storage/` isolate ABI surfaces and layouts.
- `deploy/` contains Hardhat deploy scripts; matching chain snapshots live in `deployments/`.
- `scripts/` and `constants.ts` keep operational helpers; Foundry harnesses and scenarios sit in `test/`.
- Generated outputs (`out/`, `artifacts/`, `typechain-types/`) are reproducible—never hand-edit them.

## Build, Test, and Development Commands
```bash
npm install                     # install Hardhat, Foundry bindings, and tooling
npm run build                   # forge build + regenerate typechain types
npm run test                    # run Foundry test suite
npm run coverage                # produce coverage data (lcov via coverage:report)
npm run deploy:optimism-goerli  # stage deployment; requires funded keys in .env
```
Use `forge test -vvv` for trace-heavy debugging and `npm run typechain` after ABI changes.

## Coding Style & Naming Conventions
- Prettier (`.prettierrc.yaml`) enforces 4-space indents, double quotes, trailing commas, and no semicolons in TS.
- Solidity uses `solhint:recommended` with the Prettier plugin; validate via `npx solhint 'src/**/*.sol'`.
- Contracts and libraries use PascalCase, interfaces add the `I` prefix, constants stay in ALL_CAPS.
- Pick descriptive names—for example `transferRewards` instead of `doTransfer`.

## Testing Guidelines
- Add Foundry tests in `test/` with the `.t.sol` suffix (e.g., `PerpBuyback.t.sol`) and reuse `SetUp.sol`.
- Cover happy path and revert scenarios for buyback accounting and swap flows.
- Keep traces readable by limiting `vm.prank` scopes and cheatcodes to the relevant block.
- Validate coverage on touched contracts with `forge coverage --report lcov`; reviewers rely on the HTML report from `npm run coverage:report`.

## Commit & Pull Request Guidelines
- Keep commits short, single-purpose, and imperative (`Add stale price check`, `Update CHANGELOG`).
- Separate deployment artifacts from logic refactors to simplify diffs.
- PR descriptions should list executed commands (`forge test`, `npm run deploy:optimism-goerli --dry-run`) and call out contract risks.
- Link to forum or Snapshot context when changes implement proposal work; attach ABI or UI evidence only when it improves review.

## Security & Configuration Tips
- Store deploy secrets in `.env`; never commit RPC URLs or keys.
- Keep `constants.ts` and `deployments/` synchronized before shipping a live deploy.
- When altering upgradeable storage, adjust `src/storage/` structs and document the layout change in the PR so auditors can follow.

## Proposal Implementation Constraints
- Treat the effort as a direct execution of `doc/proposal.md` with zero appetite for scope creep—only implement what the proposal demands and keep the contract surface minimal.
- The deployment target is Optimism Mainnet; prioritize staying within block gas limits over micro-optimizing gas costs, and skip complexity that only saves a handful of gas.
- Optimize for stakeholder reviewability: prefer explicit, hard-coded addresses, ratios, and flows when they make the on-chain behavior self-evident, even if it diverges from typical software engineering patterns.
- Emit events for every state mutation that affects accounting so we can reconstruct history if a migration is ever required (e.g., tracking repaid amounts and participant shares for a successor contract).
