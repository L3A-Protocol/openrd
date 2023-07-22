import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { deployments, ethers, getNamedAccounts } from "hardhat";
import { IDAO, MockERC721, TaskDrafts, TokenListGovernance } from "../../typechain-types";
import { TestSetup } from "../Helpers/TestSetup";
import { expect } from "chai";
import { days, minutes, now } from "../../utils/timeUnits";
import { ether } from "../../utils/ethersUnits";

export async function getDAO() {
  await loadFixture(TestSetup);
  const { deployer } = await getNamedAccounts();
  
  const TokenListGovernance = await ethers.getContract("devops_tokenListGovernance", deployer) as TokenListGovernance;
  const TaskDrafts = await ethers.getContract("devops_taskDrafts", deployer) as TaskDrafts;
  const NFT = await ethers.getContract("NFT", deployer) as MockERC721;

  return { TokenListGovernance, TaskDrafts, NFT, deployer };
}

describe("Department DAO Governance", function () {
  it("has members", async function () {
    const dao = await loadFixture(getDAO);
    expect(await dao.TokenListGovernance.isMember(0)).to.be.true;
  });
  
  it("reverts when no NFT", async function () {
    const dao = await loadFixture(getDAO);
    const metadata = ethers.toUtf8Bytes("0x");
    const actions : IDAO.ActionStruct[] = [];
    const start = now() + 30 * minutes;
    const end = now() + 2 * days;
    await expect(dao.TokenListGovernance.createProposal(metadata, actions, 0, start, end, 0, false, 0)).to.be.reverted;
  });
  
  it("allow when NFT", async function () {
    const dao = await loadFixture(getDAO);
    await dao.NFT.grantToken(dao.deployer, 0);
    const metadata = ethers.toUtf8Bytes("0x");
    const actions : IDAO.ActionStruct[] = [];
    const start = now() + 30 * minutes;
    const end = now() + 2 * days;
    await expect(dao.TokenListGovernance.createProposal(metadata, actions, 0, start, end, 0, false, 0)).to.not.be.reverted;
  });
  
  it("reverts when wrong NFT", async function () {
    const dao = await loadFixture(getDAO);
    await dao.NFT.grantToken(dao.deployer, 0);
    const metadata = ethers.toUtf8Bytes("0x");
    const actions : IDAO.ActionStruct[] = [];
    const start = now() + 30 * minutes;
    const end = now() + 2 * days;
    await expect(dao.TokenListGovernance.createProposal(metadata, actions, 0, start, end, 0, false, 1)).to.be.reverted;
  });
  
  it("reverts when not accepted NFT", async function () {
    const dao = await loadFixture(getDAO);
    await dao.NFT.grantToken(dao.deployer, 5);
    const metadata = ethers.toUtf8Bytes("0x");
    const actions : IDAO.ActionStruct[] = [];
    const start = now() + 30 * minutes;
    const end = now() + 2 * days;
    await expect(dao.TokenListGovernance.createProposal(metadata, actions, 0, start, end, 0, false, 5)).to.be.reverted;
  });
  
  it("allow when NFT accepted", async function () {
    const dao = await loadFixture(getDAO);
    await dao.NFT.grantToken(dao.deployer, 5);

    // Move this to a helper function (get DAO signer? execute as DAO?)
    const managementDAO = await deployments.get("management_dao");
    (await ethers.getSigners())[0].sendTransaction({
      to: managementDAO.address,
      value: ether,
    });
    await dao.TokenListGovernance.connect(await ethers.getImpersonatedSigner(managementDAO.address)).addMembers([5]);

    const metadata = ethers.toUtf8Bytes("0x");
    const actions : IDAO.ActionStruct[] = [];
    const start = now() + 30 * minutes;
    const end = now() + 2 * days;
    await expect(dao.TokenListGovernance.createProposal(metadata, actions, 0, start, end, 0, false, 5)).to.not.be.reverted;
  });
});
