import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getTokenVotingSettings } from "../utils/PluginSettings";
import { createDAO } from "../utils/DAODeployer";
import { getBool, getVar } from "../../../utils/globalVars";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  if (!(await getBool("NewERC20"))) {
    return;
  }

  const { deployments, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const subdomain = "community-test-" + (await getVar("ENSCounter"));

  const erc20Collection = await deployments.get("ERC20");
  const tokenVotingSettings = await getTokenVotingSettings(erc20Collection.address);

  const dao = await createDAO(deployer, subdomain, [tokenVotingSettings], deployments);

  await deployments.save("community_dao", {
    address: dao.daoAddress,
    ...(await deployments.getArtifact("DAO")),
  });
  await deployments.save("community_tokenVoting", {
    address: dao.pluginAddresses[0],
    ...(await deployments.getArtifact("TokenVoting")),
  });
};
export default func;
func.tags = ["CommunityDAO"];
func.dependencies = ["TokenVoting", "ERC20"];
