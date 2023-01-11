import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeploymentsKey } from "../constants"
import { PerpBuybackPool } from "../typechain-types"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    console.log(`\nRunning: ${__filename}`)

    const { ethers, deployments, getNamedAccounts } = hre

    const perpBuybackPoolDeployment = await deployments.get(DeploymentsKey.PerpBuybackPool)
    const perpBuybackPool = (await ethers.getContractAt(
        DeploymentsKey.PerpBuybackPool,
        perpBuybackPoolDeployment.address,
    )) as PerpBuybackPool

    const perpBuybackDeployment = await deployments.get(DeploymentsKey.PerpBuyback)

    if ((await perpBuybackPool.getPerpBuyback()) !== perpBuybackDeployment.address) {
        await perpBuybackPool.setPerpBuyback(perpBuybackDeployment.address)
        console.log(`Set PerpBuyback address to ${perpBuybackDeployment.address}`)
    }
}

func.tags = ["Setter"]

export default func
