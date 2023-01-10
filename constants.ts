export enum ChainId {
    OPTIMISM_CHAIN_ID = 10,
    OPTIMISM_GOERLI_CHAIN_ID = 420,
}

export enum DeploymentsKey {
    PerpBuybackPool = "PerpBuybackPool",
    PerpBuyback = "PerpBuyback",
}

export enum ContractFullyQualifiedName {
    PerpBuybackPool = "src/PerpBuybackPool.sol:PerpBuybackPool",
    PerpBuyback = "src/PerpBuyback.sol:PerpBuyback",
}

export const CONTRACT_FILES = {
    [DeploymentsKey.PerpBuybackPool]: ContractFullyQualifiedName.PerpBuybackPool,
    [DeploymentsKey.PerpBuyback]: ContractFullyQualifiedName.PerpBuyback,
}

export enum ExternalDeploymentsKey {
    DefaultProxyAdmin = "DefaultProxyAdmin",
}
