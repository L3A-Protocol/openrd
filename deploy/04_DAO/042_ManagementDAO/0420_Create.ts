import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getTokenListGovernanceSettings } from "../utils/PluginSettings";
import { createDAO } from "../utils/DAODeployer";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
	const { deployments, getNamedAccounts } = hre;
    const { deployer } = await getNamedAccounts();
    const subdomain = "management-test-0";

    const nftCollection = await deployments.get("NFT");
    const communityDao = await deployments.get("community_dao");
    const tokenListGovernanceSettings = await getTokenListGovernanceSettings(nftCollection.address, [0], communityDao.address);

    const dao = await createDAO(deployer, subdomain, [tokenListGovernanceSettings], deployments);

    await deployments.save("management_dao", { address : dao.daoAddress, abi: (await deployments.getArtifact("DAO")).abi });
    await deployments.save("management_tokenListGovernance", { address : dao.pluginAddresses[0], abi: (await deployments.getArtifact("TokenListGovernance")).abi });
};
export default func;
func.tags = ["ManagementDAO"];
func.dependencies = ["CommunityDAO"];