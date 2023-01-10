import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { CONTRACT_FILES, DeploymentsKey } from "../constants"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    console.log(`\nRunning: ${__filename}`)

    const { ethers, deployments, getNamedAccounts } = hre
    const deployer = await ethers.getNamedSigner("deployer")
    const { usdc, perp, vePerp, gnosisSafeAddress } = await getNamedAccounts()

    const perpBuybackPoolDeployment = await deployments.get(DeploymentsKey.PerpBuybackPool)
    const deploymentKey = DeploymentsKey.PerpBuyback
    const contractFullyQualifiedName = CONTRACT_FILES[deploymentKey]
    const proxyExecute = {
        init: {
            methodName: "initialize",
            args: [usdc, perp, vePerp, perpBuybackPoolDeployment.address],
        },
    }

    await deployments.deploy(deploymentKey, {
        from: deployer.address,
        contract: contractFullyQualifiedName,
        log: true,
        proxy: {
            owner: gnosisSafeAddress, // ProxyAdmin.owner
            proxyContract: "OpenZeppelinTransparentProxy",
            viaAdminContract: "DefaultProxyAdmin",
            execute: proxyExecute,
        },
    })
}

func.tags = ["PerpBuybackPool"]

export default func
