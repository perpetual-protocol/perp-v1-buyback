import "@typechain/hardhat"
import * as dotenv from "dotenv"
import "hardhat-deploy"
import "hardhat-deploy-ethers"
import { HardhatUserConfig } from "hardhat/config"
import { ChainId } from "./constants"
dotenv.config()

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.17",
        settings: {
            optimizer: { enabled: true, runs: 100 },
            evmVersion: "berlin",
            // for smock to mock contracts
            outputSelection: {
                "*": {
                    "*": ["storageLayout"],
                },
            },
        },
    },
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
            saveDeployments: true,
        },
        localhost: {
            allowUnlimitedContractSize: true,
            saveDeployments: true,
        },
        optimism: {
            url: process.env.OPTIMISM_WEB3_ENDPOINT,
            accounts: {
                mnemonic: process.env.OPTIMISM_DEPLOYER_MNEMONIC,
            },
            chainId: ChainId.OPTIMISM_CHAIN_ID,
        },
        "optimism-goerli": {
            url: process.env.OPTIMISM_GOERLI_WEB3_ENDPOINT,
            accounts: {
                mnemonic: process.env.OPTIMISM_GOERLI_DEPLOYER_MNEMONIC,
            },
            chainId: ChainId.OPTIMISM_GOERLI_CHAIN_ID,
        },
    },
    namedAccounts: {
        deployer: 0,
        gnosisSafeAddress: {
            [ChainId.OPTIMISM_CHAIN_ID]: "0x5E5c7dE5E4C223B7fA506E2C2b7328fA8388d502",
            [ChainId.OPTIMISM_GOERLI_CHAIN_ID]: "0x9E9DFaCCABeEcDA6dD913b3685c9fe908F28F58c",
        },
        usdc: {
            [ChainId.OPTIMISM_CHAIN_ID]: "0x7f5c764cbc14f9669b88837ca1490cca17c31607",
            [ChainId.OPTIMISM_GOERLI_CHAIN_ID]: "0xe5e0DE0ABfEc2FFFaC167121E51d7D8f57C8D9bC",
        },
        perp: {
            [ChainId.OPTIMISM_CHAIN_ID]: "0x9e1028f5f1d5ede59748ffcee5532509976840e0",
            [ChainId.OPTIMISM_GOERLI_CHAIN_ID]: "0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53",
        },
        vePerp: {
            [ChainId.OPTIMISM_CHAIN_ID]: "0xD360B73b19Fb20aC874633553Fb1007e9FcB2b78",
            [ChainId.OPTIMISM_GOERLI_CHAIN_ID]: "0xcD1d0954D5D00f357A0B2aB7D0625ED7c41C9245",
        },
        perpUsdChainlinkAggregator: {
            // url: https://docs.chain.link/data-feeds/price-feeds/addresses?network=optimism
            [ChainId.OPTIMISM_CHAIN_ID]: "0xA12CDDd8e986AF9288ab31E58C60e65F2987fB13",
            // mock aggregator contract on optimism-goerli, will always return 1 PERP = 10 USD
            [ChainId.OPTIMISM_GOERLI_CHAIN_ID]: "0xFd79003451Ec6E8D595Cb0408caA29BbF5BE939A",
        },
    },
    paths: {
        sources: "./src",
        tests: "./test",
        cache: "./cache",
        artifacts: "./artifacts",
    },
}

export default config
