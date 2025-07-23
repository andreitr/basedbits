# BASED BITS

Built using [Foundry](https://book.getfoundry.sh/)

### Useful Commands

- `forge test -vvv`
- `forge test --gas-report`
- `forge coverage`
- `forge coverage --report lcov`
- `forge script script/utils/CheckQuoter.s.sol --rpc-url <BASE_RPC_URL>`
  - Requires `POT_RAIDER` environment variable containing the PotRaider contract address.
  - Optionally set `AMOUNT_IN` to override the default 1 ether amount used for quoting.
