// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/MyGovernor.sol";
import "openzeppelin/governance/TimelockController.sol";
import "openzeppelin/governance/compatibility/GovernorCompatibilityBravo.sol";

contract MyGovernorTest is Test {
    MyToken private myToken;
    TimelockController private timelock;
    MyGovernor private myGovernor;

    uint256 constant TIMELOCK_MIN_DELAY = 10 seconds;

    address grantReceiver = address(10);
    uint256 grantAmount = 10 ether;

    address proposer = address(11);

    address voter1 = address(12);
    address voter2 = address(13);
    address voter3 = address(14);

    uint256 VOTER1_VOTE_POWER = 100 ether;
    uint256 VOTER2_VOTE_POWER = 50 ether;
    uint256 VOTER3_VOTE_POWER = 20 ether;

    function setUp() public {
        myToken = new MyToken();
        timelock = new TimelockController(TIMELOCK_MIN_DELAY, new address[](0), new address[](0), address(this));
        myGovernor = new MyGovernor(myToken, timelock);

        // transfer ownership to timelock contract, so after execution proposal the timelock contract can call withdraw function which has onlyOwner modifier
        myToken.transferOwnership(address(timelock));

        // Grant timelock access roles to the governor so only governor will be able to propose/cancel/execute proposals
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(myGovernor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(myGovernor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(myGovernor));

        // Set voters balances
        vm.deal(voter1, 1000000 ether);
        vm.deal(voter2, 1000000 ether);
        vm.deal(voter3, 1000000 ether);

        // Mint token so voters will have vote power
        vm.prank(voter1);
        myToken.mint{value: VOTER1_VOTE_POWER}(voter1, VOTER1_VOTE_POWER);
        vm.prank(voter2);
        myToken.mint{value: VOTER2_VOTE_POWER}(voter2, VOTER2_VOTE_POWER);
        vm.prank(voter3);
        myToken.mint{value: VOTER3_VOTE_POWER}(voter3, VOTER3_VOTE_POWER);

        // Delegate vote power to voters themselves
        vm.prank(voter1);
        myToken.delegate(voter1);
        vm.prank(voter2);
        myToken.delegate(voter2);
        vm.prank(voter3);
        myToken.delegate(voter3);
    }

    function testProposal() public {
        assertEq(myToken.getVotes(voter1), VOTER1_VOTE_POWER);
        assertEq(myToken.getVotes(voter2), VOTER2_VOTE_POWER);
        assertEq(myToken.getVotes(voter3), VOTER3_VOTE_POWER);

        // Grant receiver balance is zero
        assertEq(grantReceiver.balance, 0);

        // Create proposal to grant 10 ethers to someone
        address[] memory targets = new address[](1);
        targets[0] = address(myToken);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeCall(MyToken.withdraw, (grantReceiver, grantAmount));
        string memory description = string(abi.encodePacked("Grant 10 ethers to someone.", "#proposer=", proposer));

        // Create proposal
        vm.prank(proposer);
        uint256 proposalId = myGovernor.propose(
            targets,
            values,
            calldatas,
            description
        );

        // Passing votingDelay
        uint256 votingDelay = myGovernor.votingDelay();
        vm.roll(block.number + votingDelay + 1);

        // Cast Votes
        vm.prank(voter1);
        myGovernor.castVote(
            proposalId,
            1 // For
        );
        vm.prank(voter2);
        myGovernor.castVote(
            proposalId,
            0 // Against
        );
        vm.prank(voter3);
        myGovernor.castVote(
            proposalId,
            2 // Abstain
        );

        (,,,,,uint256 forVotes, uint256 againstVotes, uint256 abstainVotes,,) = myGovernor.proposals(proposalId);
        assertEq(forVotes, VOTER1_VOTE_POWER);
        assertEq(againstVotes, VOTER2_VOTE_POWER);
        assertEq(abstainVotes, VOTER3_VOTE_POWER);

        // Passing votingPeriod
        uint256 votingPeriod = myGovernor.votingPeriod();
        vm.roll(block.number + votingPeriod + 1);

        // Queue proposal
        myGovernor.queue(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Passing timelock delay
        skip(TIMELOCK_MIN_DELAY);

        // Execute proposal
        myGovernor.execute(
            targets,
            values,
            calldatas,
            keccak256(bytes(description))
        );

        // Grant receiver balance increased
        assertEq(grantReceiver.balance, grantAmount);
    }
}
