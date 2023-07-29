import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { setBool } from "../../utils/globalVars";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
	const { deployments, getNamedAccounts } = hre;
    const { deployer } = await getNamedAccounts();

    const deployResult = await deployments.deploy("NFT", {
        from: deployer,
        contract: "MockERC721",
        args: ["Plopmenz NFTs", "PLOP"]
    });

    await setBool("NewNFT", true);
};
export default func;
func.tags = ["NFT"];