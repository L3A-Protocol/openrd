import { ethers } from "hardhat";
import { getVar } from "../../../utils/globalVars";
import { BigNumberish } from "ethers";

// TODO allow to also override voting settings
export async function getTokenListGovernanceSettings(nftCollection : string, tokens : BigNumberish[], manager : string) {
    const tokenListGovernanceFormat = [
        "tuple(uint8 votingMode, uint64 supportThreshold, uint64 minParticipation, uint64 minDuration, uint256 minProposerVotingPower) votingSettings",
        "address tokenCollection",
        "uint256[] members",
        "address manager",
    ];
    const tokenListGovernanceValues : any[] = [
        {
            votingMode: 1, // Early execution
            supportThreshold: 50 * 10**4, // % * 10**4 (ppm)
            minParticipation: 20 * 10**4, // % * 10**4 (ppm)
            minDuration: 3600, // seconds
            minProposerVotingPower: 1, // require people to be a member to create proposals (this is a boolean in disguise)
        },
        nftCollection,
        tokens,
        manager,
    ];
    const tokenListGovernanceBytes = ethers.AbiCoder.defaultAbiCoder().encode(
        tokenListGovernanceFormat,
        tokenListGovernanceValues
    );
    const tokenListGovernanceSettings = {
        pluginSetupRef: {
            versionTag: {
                release: 1,
                build: 1,
            },
            pluginSetupRepo: await getVar("TokenListGovernanceRepo"),
        },
        data: tokenListGovernanceBytes,
    };
    return tokenListGovernanceSettings;
}

export async function geTaskDraftsSettings(tasks : string, governancePlugin : string) {
    const taskDraftsFormat = [
        "address tasks",
        "address governancePlugin",
    ];
    const taskDraftsValues : any[] = [
        tasks,
        governancePlugin,
    ];
    const taskDraftsBytes = ethers.AbiCoder.defaultAbiCoder().encode(
        taskDraftsFormat,
        taskDraftsValues
    );
    const taskDraftsSettings = {
        pluginSetupRef: {
            versionTag: {
                release: 1,
                build: 1,
            },
            pluginSetupRepo: await getVar("TaskDraftsRepo"),
        },
        data: taskDraftsBytes,
    };
    return taskDraftsSettings;
}