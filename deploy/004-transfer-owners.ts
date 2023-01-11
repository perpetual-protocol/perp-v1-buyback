import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeploymentsKey, ExternalDeploymentsKey } from "../constants"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    console.log(`\nRunning: ${__filename}`)

    const { ethers, deployments, getNamedAccounts } = hre

    const { gnosisSafeAddress } = await getNamedAccounts()

    const proxyAdminDeployment = await deployments.get(ExternalDeploymentsKey.DefaultProxyAdmin)
    const proxyAdmin = await ethers.getContractAt(proxyAdminDeployment.abi, proxyAdminDeployment.address)
    if ((await proxyAdmin.owner()) !== gnosisSafeAddress) {
        console.log(`Transferring owner ${ExternalDeploymentsKey.DefaultProxyAdmin}`)
        await (await proxyAdmin.transferOwnership(gnosisSafeAddress)).wait()
    }

    const deploymentsKeys = Object.keys(DeploymentsKey)
    for (const deploymentKey of deploymentsKeys) {
        console.log(`Transferring ${deploymentKey}'s owner to ${gnosisSafeAddress}`)

        let owner: string | null
        try {
            owner = await deployments.read(deploymentKey, "owner")
        } catch (err) {
            if (err.message.includes(`no method named "owner" on contract`)) {
                console.log(`Skip since ${deploymentKey} is not SafeOwnable`)
                return
            } else {
                throw err
            }
        }
        console.log(`${deploymentKey}.owner() = ${owner}`)

        const pendingOwner = await deployments.read(deploymentKey, "pendingOwner")
        console.log(`${deploymentKey}.pendingOwner() = ${pendingOwner}`)

        if (owner !== gnosisSafeAddress) {
            if (pendingOwner !== gnosisSafeAddress) {
                await this.execute(deploymentKey, "transferOwnership", [gnosisSafeAddress])
                await this.execute(deploymentKey, "acceptOwnership", [], { from: gnosisSafeAddress })
            } else {
                await this.execute(deploymentKey, "acceptOwnership", [], { from: gnosisSafeAddress })
            }
        } else {
            console.log(`${deploymentKey}'s owner is already transferred to ${gnosisSafeAddress}`)
        }
    }
}

func.tags = ["transfer-owners"]

export default func
