pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./EscrowFactory.sol";

contract EscrowExchange is EscrowFactory {

	event ContractCreated(address buyer, address seller, uint amount, uint deposit, uint signatureCount, string status, string notes);

	function getContractForCurrentUser(uint index) public view returns (address, address, uint, uint, uint, string memory, string memory notes){
		EscrowContract memory retrieved_contract = contractsForUser[msg.sender][index];
        return (retrieved_contract.buyer, retrieved_contract.seller, retrieved_contract.amount, retrieved_contract.deposit, retrieved_contract.signatureCount, checkStatus(uint(retrieved_contract.status)), retrieved_contract.notes);
    }

    function getContractCountForCurrentUser() external view returns (uint) {
    	return ownerContractCount[msg.sender];
    }

    function createContract(address payable buyer, address payable seller, uint amount, uint deposit, string memory notes) public {
    	EscrowContract memory newContract = _createContract(buyer, seller, amount, deposit, notes);
    	// For looping through contracts later on.
    	contractsForUser[buyer].push(newContract);
    	contractsForUser[seller].push(newContract);
    	ownerContractCount[buyer] = ownerContractCount[buyer].add(1);
    	ownerContractCount[seller] = ownerContractCount[seller].add(1);

    	emit ContractCreated(buyer, seller, amount, deposit, 0, "Open", notes);
    }

    function checkStatus(uint id) private view returns (string memory){

        string memory status = "";

        if (uint(contractsForUser[msg.sender][id].status) == 0){
            status = "Open";
        } else if (uint(contractsForUser[msg.sender][id].status) == 1){
            status = "Pending";
        } else{
            status = "Closed";
        }

        return (status);
    }
} 