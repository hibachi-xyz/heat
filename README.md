# HEAT Token

HEAT is the core token of the Hibachi protocol.

## Access Control

There are two access control hierarchies:
- the `owner` (from `Ownable`) is responsible for LayerZero configuration
- role-based access

There are two defined roles aside from the DEFAULT_ADMIN:
- MINTER_ROLE - allowed to mint more HEAT tokens
- FREEZE_ROLE - allowed to freeze the token globally or individual accounts

Both DEFAULT_ADMIN and MINTER_ROLE should be held by time locks.

## Freezing

HEAT transfers can be frozen either globally or at a per account level.
This could be used in situations such as:
- the LayerZero bridge is compromised
- compliance (e.g. hacked funds)

Freezing includes preventing accounts from spending / granting allowance.

## Cross-Chain

HEAT is natively a LayerZero OFT, which means that it can be sent cross-chain.
HEAT uses 6 shared decimals between the LayerZero supported chains.

### Configuration

For each chain deployment, HEAT needs the following configuration:
- configuration overrides for each path (src/dst) that specify at least 2 DVNs
- peer address setting
- enforced options