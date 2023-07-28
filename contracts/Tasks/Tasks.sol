// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

import { ITasks, IERC20, Escrow } from "./ITasks.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";

contract Tasks is Context, ITasks {
    /// @notice The incremental ID for tasks.
    uint256 private taskCounter;

    /// @notice Various statistics about total tasks.
    uint256 private openTasks;
    uint256 private takenTasks;
    uint256 private successfulTasks;

    /// @notice A mapping between task IDs and task information.
    mapping(uint256 => Task) internal tasks;

    /// @notice The base escrow contract that will be cloned for every task.
    address private escrowImplementation;

    constructor() {
        escrowImplementation = address(new Escrow());
    }

    /// @inheritdoc ITasks
    function taskCount() external view returns (uint256) {
        return taskCounter;
    }
    
    /// @inheritdoc ITasks
    function taskStatistics() external view returns (uint256 open, uint256 taken, uint256 successful) {
        (open, taken, successful) = (openTasks, takenTasks, successfulTasks);
    }

    /// @inheritdoc ITasks
    function getTask(
        uint256 _taskId
    ) public view returns (OffChainTask memory offchainTask) {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }

        Task storage task = tasks[_taskId];
        offchainTask.metadata = task.metadata;
        offchainTask.deadline = task.deadline;
        offchainTask.executorApplication = task.executorApplication;
        offchainTask.proposer = task.proposer;
        offchainTask.state = task.state;
        offchainTask.escrow = task.escrow;

        offchainTask.budget = new ERC20Transfer[](task.budgetCount);
        for (uint8 i; i < offchainTask.budget.length; ) {
            offchainTask.budget[i] = task.budget[i];
            unchecked {
                ++i;
            }
        }
        
        offchainTask.applications = new OffChainApplication[](task.applicationCount);
        for (uint8 i; i < offchainTask.applications.length; ) {
            Application storage application = task.applications[i];
            offchainTask.applications[i].metadata = application.metadata;
            offchainTask.applications[i].applicant = application.applicant;
            offchainTask.applications[i].accepted = application.accepted;
            offchainTask.applications[i].reward = new Reward[](application.rewardCount);
            for (uint8 j; j < offchainTask.applications[i].reward.length; ) {
                offchainTask.applications[i].reward[j] = application.reward[j];
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }

        offchainTask.submissions = new Submission[](task.submissionCount);
        for (uint8 i; i < offchainTask.submissions.length; ) {
            offchainTask.submissions[i] = task.submissions[i];
            unchecked {
                ++i;
            }
        }

        // offchainTask.changeScopeRequests = new OffChainChangeScopeRequest[](task.changeScopeRequestCount);
        // for (uint8 i; i < offchainTask.changeScopeRequests.length; ) {
        //     offchainTask.changeScopeRequests[i].metadata = task.changeScopeRequests[i].metadata;
        //     offchainTask.changeScopeRequests[i].accepted = task.changeScopeRequests[i].accepted;
        //     offchainTask.changeScopeRequests[i].deadline = task.changeScopeRequests[i].deadline;
        //     offchainTask.changeScopeRequests[i].reward = new Reward[](task.changeScopeRequests[i].rewardCount);
        //     for (uint8 j; j < offchainTask.changeScopeRequests[i].reward.length; ) {
        //         offchainTask.changeScopeRequests[i].reward[j] = task.changeScopeRequests[i].reward[j];
        //         unchecked {
        //             ++j;
        //         }
        //     }
        //     unchecked {
        //         ++i;
        //     }
        // }

        // offchainTask.dropExecutorRequests = new DropExecutorRequest[](task.dropExecutorRequestCount);
        // for (uint8 i; i < offchainTask.dropExecutorRequests.length; ) {
        //     offchainTask.dropExecutorRequests[i] = task.dropExecutorRequests[i];
        //     unchecked {
        //         ++i;
        //     }
        // }

        offchainTask.cancelTaskRequests = new CancelTaskRequest[](task.cancelTaskRequestCount);
        for (uint8 i; i < offchainTask.cancelTaskRequests.length; ) {
            offchainTask.cancelTaskRequests[i] = task.cancelTaskRequests[i];
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc ITasks
    function getTasks(
        uint256[] memory _taskIds
    ) public view returns (OffChainTask[] memory) {
        OffChainTask[] memory offchainTasks = new OffChainTask[](_taskIds.length);
        for (uint i; i < _taskIds.length; ) {
            offchainTasks[i] = getTask(_taskIds[i]);

            unchecked {
                ++i;
            }
        }
        return offchainTasks;
    }
    
    /// @inheritdoc ITasks
    function getProposingTasks(
        address _proposer,
        uint256 _fromTaskId,
        uint256 _max
    ) external view returns (OffChainTask[] memory) {
        uint256 totalTasks = taskCounter;
        uint256[] memory taskIndexes = new uint256[](totalTasks);
        uint256 proposerTasksCount;
        if (_fromTaskId == 0) {
            _fromTaskId = totalTasks - 1;
        }
        for (uint i = _fromTaskId; i != type(uint).max; ) {
            if (tasks[i].proposer == _proposer) {
                taskIndexes[proposerTasksCount] = i;
                unchecked {
                    ++proposerTasksCount;
                }
                if (proposerTasksCount == _max) {
                    // _max == 0 never triggering is on purpose
                    break;
                }
            }

            unchecked {
                --i;
            }
        }
        // decrease length of array to match real entries
        assembly { mstore(taskIndexes, sub(mload(taskIndexes), sub(totalTasks, proposerTasksCount))) }
        return getTasks(taskIndexes);
    }
    
    /// @inheritdoc ITasks
    function getExecutingTasks(
        address _executor,
        uint256 _fromTaskId,
        uint256 _max
    ) external view returns (OffChainTask[] memory) {
        uint256 totalTasks = taskCounter;
        uint256[] memory taskIndexes = new uint256[](totalTasks);
        uint256 executorTasksCount;
        if (_fromTaskId == 0) {
            _fromTaskId = totalTasks - 1;
        }
        for (uint i = _fromTaskId; i != type(uint).max; ) {
            if (tasks[i].state != TaskState.Open && tasks[i].applications[tasks[i].executorApplication].applicant == _executor) {
                taskIndexes[executorTasksCount] = i;
                unchecked {
                    ++executorTasksCount;
                }
                if (executorTasksCount == _max) {
                    // _max == 0 never triggering is on purpose
                    break;
                }
            }

            unchecked {
                --i;
            }
        }
        // decrease length of array to match real entries
        assembly { mstore(taskIndexes, sub(mload(taskIndexes), sub(totalTasks, executorTasksCount))) }
        return getTasks(taskIndexes);
    }

    /// @inheritdoc ITasks
    function createTask(
        string calldata _metadata,
        uint64 _deadline,
        ERC20Transfer[] calldata _budget,
        address _manager,
        PreapprovedApplication[] calldata _preapprove
    ) external returns (uint256 taskId) {
        unchecked {
            taskId = taskCounter++;
        }

        Task storage task = tasks[taskId];
        task.metadata = _metadata;
        task.deadline = _deadline;
        task.budgetCount = uint8(_budget.length);
        Escrow escrow = Escrow(Clones.clone(escrowImplementation));
        escrow.__Escrow_init();
        task.escrow = escrow;
        for (uint8 i; i < _budget.length; ) {
            _budget[i].tokenContract.transferFrom(_msgSender(), address(escrow), _budget[i].amount);
            task.budget[i] = _budget[i];
            unchecked {
                ++i;
            }
        }
        
        task.proposer = _manager;

        // Default values are already correct (save gas)
        // task.state = TaskState.Open;
        unchecked {
            ++openTasks;
        }

        if (_preapprove.length > 0) {
            task.applicationCount = uint16(_preapprove.length);
            for (uint16 i; i < _preapprove.length; ) {
                Application storage application = task.applications[i];
                application.applicant = _preapprove[i].applicant;
                application.accepted = true;
                _setRewardBellowBudget(task, application, _preapprove[i].reward);

                unchecked {
                    ++i;
                }
            }
        }

        emit TaskCreated(taskId, _metadata, _deadline, _budget, _manager, _preapprove);
    }

    /// @inheritdoc ITasks
    function applyForTask(
        uint256 _taskId,
        string calldata _metadata,
        Reward[] calldata _reward
    ) external returns (uint16 applicationId) {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }

        Task storage task = tasks[_taskId];
        if (task.state != TaskState.Open) {
            revert TaskNotOpen();
        }

        Application storage application = task.applications[task.applicationCount];
        application.metadata = _metadata;
        application.applicant = _msgSender();
        application.rewardCount = uint8(_reward.length);
        for (uint8 i; i < uint8(_reward.length); ) {
            application.reward[i] = _reward[i];
            unchecked {
                ++i;
            }
        }

        unchecked {
            applicationId = task.applicationCount++;
        }

        emit ApplicationCreated(_taskId, applicationId, _metadata, _reward, task.proposer, _msgSender());
    }
    
    /// @inheritdoc ITasks
    function acceptApplications(
        uint256 _taskId,
        uint16[] calldata _applications
    ) external {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }
        
        Task storage task = tasks[_taskId];
        if (task.state != TaskState.Open) {
            revert TaskNotOpen();
        }
        if (task.proposer != _msgSender()) {
            revert NotProposer();
        }

        for (uint i; i < _applications.length; ) {
            if (_applications[i] >= task.applicationCount) {
                revert ApplicationDoesNotExist();
            }
            
            Application storage application_ = task.applications[_applications[i]];
            application_.accepted = true;
            _increaseBudgetToReward(task, application_.rewardCount, application_.reward);
            emit ApplicationAccepted(_taskId, uint16(i), _msgSender(), application_.applicant);
            
            unchecked {
                ++i;
            }
        }
    }
    
    /// @inheritdoc ITasks
    function takeTask(
        uint256 _taskId,
        uint16 _application
    ) external {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }
        
        Task storage task = tasks[_taskId];
        if (task.state != TaskState.Open) {
            revert TaskNotOpen();
        }
        if (_application >= task.applicationCount) {
            revert ApplicationDoesNotExist();
        }

        Application storage application_ = task.applications[_application];
        if (application_.applicant != _msgSender()) {
            revert NotYourApplication();
        }
        if (!application_.accepted) {
            revert ApplicationNotAccepted();
        }

        task.executorApplication = _application;

        task.state = TaskState.Taken;
        unchecked {
            --openTasks;
            ++takenTasks;
        }

        emit TaskTaken(_taskId, _application, task.proposer, _msgSender());
    }
    
    /// @inheritdoc ITasks
    function createSubmission(
        uint256 _taskId,
        string calldata _metadata
    ) external returns (uint8 submissionId) {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }
        
        Task storage task = tasks[_taskId];
        if (task.state != TaskState.Taken) {
            revert TaskNotTaken();
        }
        if (task.applications[task.executorApplication].applicant != _msgSender()) {
            revert NotExecutor();
        }

        Submission storage submission_ = task.submissions[task.submissionCount];
        submission_.metadata = _metadata;
        unchecked { 
            submissionId = task.submissionCount++;
        }

        emit SubmissionCreated(_taskId, submissionId, _metadata, task.proposer, _msgSender());
    }
    
    /// @inheritdoc ITasks
    function reviewSubmission(
        uint256 _taskId,
        uint8 _submission,
        SubmissionJudgement _judgement,
        string calldata _feedback
    ) external {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }
        
        Task storage task = tasks[_taskId];
        if (task.state != TaskState.Taken) {
            revert TaskNotTaken();
        }
        if (task.proposer != _msgSender()) {
            revert NotProposer();
        }
        if (_submission >= task.submissionCount) {
            revert SubmissionDoesNotExist();
        }

        Submission storage submission_ = task.submissions[_submission];
        if (submission_.judgement != SubmissionJudgement.None) {
            revert SubmissionAlreadyJudged();
        }
        submission_.judgement = _judgement;
        submission_.feedback = _feedback;

        if (_judgement == SubmissionJudgement.Accepted) {
            Application storage executor = task.applications[task.executorApplication];
            address proposer = _msgSender(); // task.proposer;
            Escrow escrow = task.escrow;

            uint8 j;
            ERC20Transfer memory erc20Transfer = task.budget[0];
            uint8 rewardCount = executor.rewardCount;
            for (uint8 i; i < rewardCount; ) {
                Reward memory reward = executor.reward[i];
                escrow.transfer(erc20Transfer.tokenContract, executor.applicant, reward.amount);
                unchecked {
                    erc20Transfer.amount -= reward.amount;
                }

                if (reward.nextToken) {
                    if (erc20Transfer.amount > 0) {
                        escrow.transfer(erc20Transfer.tokenContract, proposer, erc20Transfer.amount);
                    }

                    unchecked {
                        erc20Transfer = task.budget[++j];
                    }
                }

                unchecked {
                    ++i;
                }
            }
            uint8 budgetCount = task.budgetCount;
            while (j < budgetCount) {
                escrow.transfer(erc20Transfer.tokenContract, proposer, erc20Transfer.amount);
                
                unchecked {
                    erc20Transfer = task.budget[++j];
                }
            }

            task.state = TaskState.Closed;
            unchecked {
                --takenTasks;
                ++successfulTasks;
            }

            emit TaskCompleted(_taskId, proposer, executor.applicant);
        }

        emit SubmissionReviewed(_taskId, _submission, _judgement, _feedback, _msgSender(), task.applications[task.executorApplication].applicant);
    }
    
    /// @inheritdoc ITasks
    // function changeScope(
    //     uint256 _taskId,
    //     string calldata _newMetadata,
    //     uint64 _newDeadline,
    //     Reward[] calldata _newReward
    // ) external returns (uint8 changeTaskRequestId) {
        // if (_taskId >= taskCounter) {
        //     revert TaskDoesNotExist();
        // }

        // Task storage task = tasks[_taskId];
        // if (task.state != TaskState.Taken) {
        //     revert TaskNotTaken();
        // }
        // if (task.proposer != _msgSender()) {
        //     revert NotProposer();
        // }

        // ChangeScopeRequest storage request = task.changeScopeRequests[task.changeScopeRequestCount];
        // request.metadata = _newMetadata;
        // request.timestamp = uint64(block.timestamp);
        // request.deadline = _newDeadline;
        // request.rewardCount = uint8(_newReward.length);

        // uint8 j;
        // ERC20Transfer memory erc20Transfer = task.budget[0];
        // uint256 needed;
        // for (uint8 i; i < uint8(_newReward.length); ) {
        //     unchecked {
        //         needed += _newReward[i].amount;
        //     }

        //     request.reward[i] = _newReward[i];

        //     if (_newReward[i].nextToken) {
        //         if (needed > erc20Transfer.amount) {
        //             // Excisting budget in escrow doesnt cover the new reward
        //             erc20Transfer.tokenContract.transferFrom(_msgSender(), address(task.escrow), needed - erc20Transfer.amount);
        //         }

        //         needed = 0;
        //         unchecked {
        //             erc20Transfer = task.budget[++j];
        //         }
        //     }

        //     unchecked {
        //         ++i;
        //     }
        // }

        // unchecked {
        //     changeTaskRequestId = task.changeScopeRequestCount++;
        // }
        
        // emit ChangeScopeRequested(_taskId, changeTaskRequestId, _msgSender(), _newMetadata, _newDeadline, _newReward);
    // }

    /// @inheritdoc ITasks
    // function dropExecutor(
    //     uint256 _taskId,
    //     string calldata _explanation
    // ) external returns (uint8 dropExecutorRequestId) {
        // if (_taskId >= taskCounter) {
        //     revert TaskDoesNotExist();
        // }

        // Task storage task = tasks[_taskId];
        // if (task.state != TaskState.Taken) {
        //     revert TaskNotTaken();
        // }
        // if (task.proposer != _msgSender()) {
        //     revert NotProposer();
        // }

        // DropExecutorRequest storage request = task.dropExecutorRequests[task.dropExecutorRequestCount];
        // request.explanation = _explanation;
        // request.timestamp = uint64(block.timestamp);
        // unchecked {
        //     dropExecutorRequestId = task.dropExecutorRequestCount++;
        // }

        // emit DropExecutorRequested(_taskId, dropExecutorRequestId, _msgSender(), _explanation);
    // }

    /// @inheritdoc ITasks
    function cancelTask(
        uint256 _taskId,
        string calldata _explanation
    ) external returns (uint8 cancelTaskRequestId) {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }

        Task storage task = tasks[_taskId];
        if (task.proposer != _msgSender()) {
            revert NotProposer();
        }

        if (task.state == TaskState.Closed) {
            revert TaskClosed();
        }

        if (task.state == TaskState.Open || task.deadline <= uint64(block.timestamp)) {
            // Task is open or deadline past
            _refundProposer(task);
            emit TaskCancelled(_taskId, _msgSender(), task.state == TaskState.Open ? address(0) : task.applications[task.executorApplication].applicant);
            // Max means no request
            cancelTaskRequestId = type(uint8).max;
        }
        else {
            // Task is taken and deadline has not past
            CancelTaskRequest storage request = task.cancelTaskRequests[task.cancelTaskRequestCount];
            request.explanation = _explanation;
            unchecked {
                cancelTaskRequestId = task.cancelTaskRequestCount++;
            }

            emit CancelTaskRequested(_taskId, cancelTaskRequestId, _explanation, _msgSender(), task.applications[task.executorApplication].applicant);
        }
    }

    /// @inheritdoc ITasks
    function acceptRequest(
        uint256 _taskId,
        RequestType _requestType,
        uint8 _requestId,
        bool _execute
    ) external {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }

        Task storage task = tasks[_taskId];
        if (task.state != TaskState.Taken) {
            revert TaskNotTaken();
        }
        if (task.applications[task.executorApplication].applicant != _msgSender()) {
            revert NotExecutor();
        }
        
        if (_requestType == RequestType.ChangeScope) {
            // if (_requestId >= task.changeScopeRequestCount) {
            //     revert RequestDoesNotExist();
            // }

            // ChangeScopeRequest storage request = task.changeScopeRequests[_requestId];
            // if (request.accepted != 0) {
            //     revert RequestAlreadyAccepted();
            // }

            // task.metadata = request.metadata;
            // task.deadline = request.deadline;
            // task.changed = true;
            // Application storage executor = task.applications[task.executorApplication];
            // uint8 rewardCount = request.rewardCount;
            // executor.rewardCount = rewardCount;
            // for (uint8 i; i < rewardCount; ) {
            //     executor.reward[i] = request.reward[i];

            //     unchecked {
            //         ++i;
            //     }
            // }

            // request.accepted = uint64(block.timestamp);
        } else if (_requestType == RequestType.DropExecutor) {
            // if (_requestId >= task.dropExecutorRequestCount) {
            //     revert RequestDoesNotExist();
            // }
            
            // DropExecutorRequest storage request = task.dropExecutorRequests[_requestId];
            // if (request.accepted != 0) {
            //     revert RequestAlreadyAccepted();
            // }

            // task.submissionCount = 0;
            // if (task.changed) {
            //     task.applicationCount = 0;
            //     task.changed = false; // hmm maybe questionable, would be better in case the new executor is dropped again and the task is not changed again, but does not make sense ux wise
            // }

            // task.state = TaskState.Open;
            // unchecked {
            //     --takenTasks;
            //     ++openTasks;
            // }

            // request.accepted = uint64(block.timestamp);
        } else { // if (_requestType == RequestType.CancelTask) {
            if (_requestId >= task.cancelTaskRequestCount) {
                revert RequestDoesNotExist();
            }
            
            CancelTaskRequest storage request = task.cancelTaskRequests[_requestId];
            if (request.accepted) {
                revert RequestAlreadyAccepted();
            }

            if (_execute) {
                // use executeRequest here? (more gas due to all the checks...)
                _refundProposer(task);
                emit TaskCancelled(_taskId, task.proposer, _msgSender());
                request.executed = true;
            }

            request.accepted = true;
        }

        emit RequestAccepted(_taskId, _requestType, _requestId, task.proposer, _msgSender());
    }

    /// @inheritdoc ITasks
    function executeRequest(
        uint256 _taskId,
        RequestType _requestType,
        uint8 _requestId
    ) external {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }

        Task storage task = tasks[_taskId];
        if (task.state != TaskState.Taken) {
            revert TaskNotTaken();
        }
        
        if (_requestType == RequestType.ChangeScope) {
            // if (_requestId >= task.changeScopeRequestCount) {
            //     revert RequestDoesNotExist();
            // }

            // ChangeScopeRequest storage request = task.changeScopeRequests[_requestId];
            // if (request.accepted != 0) {
            //     revert RequestAlreadyAccepted();
            // }

            // task.metadata = request.metadata;
            // task.deadline = request.deadline;
            // task.changed = true;
            // Application storage executor = task.applications[task.executorApplication];
            // uint8 rewardCount = request.rewardCount;
            // executor.rewardCount = rewardCount;
            // for (uint8 i; i < rewardCount; ) {
            //     executor.reward[i] = request.reward[i];

            //     unchecked {
            //         ++i;
            //     }
            // }

            // request.accepted = uint64(block.timestamp);
        } else if (_requestType == RequestType.DropExecutor) {
            // if (_requestId >= task.dropExecutorRequestCount) {
            //     revert RequestDoesNotExist();
            // }
            
            // DropExecutorRequest storage request = task.dropExecutorRequests[_requestId];
            // if (request.accepted != 0) {
            //     revert RequestAlreadyAccepted();
            // }

            // task.submissionCount = 0;
            // if (task.changed) {
            //     task.applicationCount = 0;
            //     task.changed = false; // hmm maybe questionable, would be better in case the new executor is dropped again and the task is not changed again, but does not make sense ux wise
            // }

            // task.state = TaskState.Open;
            // unchecked {
            //     --takenTasks;
            //     ++openTasks;
            // }

            // request.accepted = uint64(block.timestamp);
        } else { // if (_requestType == RequestType.CancelTask) {
            if (_requestId >= task.cancelTaskRequestCount) {
                revert RequestDoesNotExist();
            }
            
            CancelTaskRequest storage request = task.cancelTaskRequests[_requestId];
            if (!request.accepted) {
                revert RequestNotAccepted();
            }
            if (request.executed) {
                revert RequestAlreadyExecuted();
            }

            _refundProposer(task);
            emit TaskCancelled(_taskId, task.proposer, task.applications[task.executorApplication].applicant);
            request.executed = true;
        }

        emit RequestExecuted(_taskId, _requestType, _requestId, _msgSender(), task.proposer, task.applications[task.executorApplication].applicant);
    }

    /// @inheritdoc ITasks
    function extendDeadline(
        uint256 _taskId,
        uint64 _extension
    ) external {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }

        Task storage task = tasks[_taskId];
        if (task.proposer != _msgSender()) {
            revert NotProposer();
        }

        if (task.state == TaskState.Closed) {
            revert TaskClosed();
        }

        task.deadline += _extension;

        emit DeadlineExtended(_taskId, _extension, _msgSender(), task.state == TaskState.Open ? address(0) : task.applications[task.executorApplication].applicant);
    }

    /// @inheritdoc ITasks
    function increaseBudget(
        uint256 _taskId,
        uint96[] calldata _increase
    ) external {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }

        Task storage task = tasks[_taskId];
        if (task.proposer != _msgSender()) {
            revert NotProposer();
        }

        if (task.state != TaskState.Open) {
            revert TaskNotOpen();
        }

        for (uint8 i; i < _increase.length; ) {
            ERC20Transfer storage transfer = task.budget[i];
            transfer.tokenContract.transferFrom(_msgSender(), address(task.escrow), _increase[i]);
            transfer.amount += _increase[i];

            unchecked {
                ++i;
            }
        }

        emit BudgetIncreased(_taskId, _increase, _msgSender());
    }

    /// @inheritdoc ITasks
    function editMetadata(
        uint256 _taskId,
        string calldata _newMetadata
    ) external {
        if (_taskId >= taskCounter) {
            revert TaskDoesNotExist();
        }

        Task storage task = tasks[_taskId];
        if (task.proposer != _msgSender()) {
            revert NotProposer();
        }

        if (task.state != TaskState.Open) {
            revert TaskNotOpen();
        }

        task.metadata = _newMetadata;
        emit MetadataEditted(_taskId, _newMetadata, _msgSender());
    }

    function _increaseBudgetToReward(
        Task storage task,
        uint8 _length,
        mapping(uint8 => Reward) storage _reward
    ) internal {
        uint8 j;
        ERC20Transfer memory erc20Transfer = task.budget[0];
        uint256 needed;
        for (uint8 i; i < _length; ) {
            unchecked {
                needed += _reward[i].amount;
            }

            if (_reward[i].nextToken) {
                if (needed > erc20Transfer.amount) {
                    // Existing budget in escrow doesnt cover the n reward
                    erc20Transfer.tokenContract.transferFrom(_msgSender(), address(task.escrow), needed - erc20Transfer.amount);
                }

                needed = 0;
                unchecked {
                    erc20Transfer = task.budget[++j];
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _setRewardBellowBudget(
        Task storage task,
        Application storage application, 
        Reward[] calldata _reward
    ) internal {
        application.rewardCount = uint8(_reward.length);

        uint8 j;
        ERC20Transfer memory erc20Transfer = task.budget[0];
        uint256 alreadyReserved;
        for (uint8 i; i < uint8(_reward.length); ) {
            // erc20Transfer.amount -= _reward[i].amount (underflow error, but that is not a nice custom once)
            unchecked {
                alreadyReserved += _reward[i].amount;
            }
            if (alreadyReserved > erc20Transfer.amount) {
                revert RewardAboveBudget(i);
            }

            application.reward[i] = _reward[i];

            if (_reward[i].nextToken) {
                alreadyReserved = 0;
                unchecked {
                    erc20Transfer = task.budget[++j];
                }
            }

            unchecked {
                ++i;
            }
        }
    }
    
    function _refundProposer(Task storage task) internal {
        uint8 budgetCount = task.budgetCount;
        address proposer = task.proposer;
        Escrow escrow = task.escrow;
        for (uint8 i; i < budgetCount; ) {
            ERC20Transfer memory erc20Transfer = task.budget[i];
            escrow.transfer(erc20Transfer.tokenContract, proposer, erc20Transfer.amount);

            unchecked {
                ++i;
            }
        }

        if (task.state == TaskState.Open) {
            unchecked {
                --openTasks;
            }
        } else if (task.state == TaskState.Taken) {
            unchecked {
                --takenTasks;
            }
        }
        task.state = TaskState.Closed;

        // Possibly could do some assembly trickery here to get the index of the task and emit TaskCancelled
    }
}