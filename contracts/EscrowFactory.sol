pragma solidity 0.5.16;

library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns(uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns(uint256) {
        assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns(uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns(uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

contract EscrowFactory {
    using SafeMath for uint256;

    enum Status { OPEN, PENDING, CLOSED }

    //storage
    
    address payable buyer;
    address payable seller;
    address[] public party;
    uint amount;
    uint deposit;
    uint signatureCount;
    Status public status;
    string public notes;
    mapping (address => bool) isAParty;
    mapping (address => uint) public signatures;
    mapping (address => uint) public depositCheck;
    mapping (address => uint) public amountCheck;

    //modifiers
    //only buyer can access
    modifier isBuyer(address sender) {
        require(sender == buyer);
        _;
    }

    //only seller can access
    modifier isSeller(address sender) {
        require(sender == seller);
        _;
    }

    //only the parties involved in the transaction can access.
    modifier ifIsAParty(address aParty) {
        require(isAParty[aParty]);
        _;
    }

     //events
    event BuyerDeposited(address from, string msg, uint amount);
    event SellerDeposited(address from, string msg, uint amount);
    event BuyerDepositReversed(string msg);
    event SellerDepositReversed(string msg);
    event DepositPartialClaim(string msg);
    event DepositsClaimed(string msg);
    event AmountSent(string msg);
    event SellerPaid(string msg);
    event BuyerRefunded(string msg);

    constructor(address payable _buyer, address payable _seller, uint _amount, uint _deposit, string memory _notes) public {
        buyer = _buyer;
        seller = _seller;
        amount = _amount;
        deposit = _deposit;
        notes = _notes;
        status = Status.OPEN;
        party.push(_buyer);
        party.push(_seller);
        isAParty[_buyer] = true;
        isAParty[_seller] = true;
    }

    /* Deposit function for the buyer - checks that the message sender
    is the buyer, the amount being sent is equal to the deposit amount
    and restricts the buyer from depositing more than once - TESTED*/
    function buyerDeposit(address buyer_address, uint deposit_amount) public payable isBuyer(buyer_address) {
        require(deposit_amount == deposit, "Invalid deposit"); // Require value submitted is equal to the deposit in the contract.
        require(depositCheck[buyer_address] == 0, "Buyer already deposited"); // Require buyer has not deposited yet
        depositCheck[buyer_address] = 1; // Set buyer deposited to true
        emit BuyerDeposited(buyer_address, "has made the required deposit of", deposit_amount);
    }

    /* Deposit function for the seller - checks that the message sender
    is the seller, the amount being sent is equal to the deposit amount
    and restricts the seller from depositing more than once - TESTED*/
    function sellerDeposit(address seller_address, uint deposit_amount) public payable isSeller(seller_address) {
        require(deposit_amount == deposit, "Invalid deposit"); // Require value submitted is equal to the deposit in the contract.
        require(depositCheck[seller_address] == 0,  "Seller already deposited"); // Require seller has not deposited yet
        depositCheck[seller_address] = 1;// Set seller deposited to true
        emit SellerDeposited(seller_address, "has made the required deposit of", deposit_amount);
    }

    /* Function for buyer to retrieve deposit in the scenario where only the
    buyer has interacted with the contract and the transaction is no longer
    going ahead.*/

    function reverseBuyerDeposit(address buyer_address) public isBuyer(buyer_address) {
        require(depositCheck[buyer] == 1, "the buyer has not desposited CANNOT reverseDeposit");
        require(depositCheck[seller] == 0, "the seller has deposited already CANNOT reverseDeposit");
        require(amountCheck[buyer] == 0, "the buyer has already sent the amount CANNOT reverseDeposit"); // To Do: Write a amountcheck test
        depositCheck[buyer] = 0;
        buyer.transfer(deposit);
        emit BuyerDepositReversed("the buyer has reversed their deposit");
    }

    /* Function for seller to retrieve deposit in the scenario where only the
    seller has interacted with the contract and the transaction is no longer
    going ahead.*/

    function reverseSellerDeposit(address seller_address) public isSeller(seller_address) {
        require(depositCheck[seller] == 1);
        require(depositCheck[buyer] == 0);
        require(amountCheck[buyer] == 0);
        depositCheck[seller] = 0;
        seller.transfer(deposit);
        emit SellerDepositReversed("the seller has reversed their deposit");
    }

    /* Function for both parties to reverse their deposits when both the buyer
    and seller have made their deposits but no longer wish to proceed, both must
    sign off on this by calling this function - TESTED*/

    function claimDeposits(address sender) public ifIsAParty(msg.sender) {
        require(depositCheck[buyer] == 1, "the buyer has not made a deposit for claimDeposits");
        require(depositCheck[seller] == 1, "the seller has not made a deposit for claimDeposits");
        require(amountCheck[buyer] == 0, "the buyer has already sent an amount for claimDeposits"); // TODO TEST
        require(signatures[sender] == 0, "the sender have already signed off on claimDeposit");
        signatures[sender] = 1;
        signatureCount ++;

        if (signatureCount == 1) {
            emit DepositPartialClaim("the deposit claim has 1 out of 2 necessary signatures");
        }

        if (signatureCount == 2) {
            buyer.transfer(deposit);
            seller.transfer(deposit);
            depositCheck[buyer] = 0;
            depositCheck[seller] = 0;
            signatures[buyer] = 0;
            signatures[seller] = 0;
            signatureCount = 0;
            emit DepositsClaimed("the deposits have been returned");
        }
    }

    /* Function to allow the buyer to send the amount which is to eventually
    be transferred to the seller. Checks that the buyer is sending the correct
    amount, checks that both seller and buyer have made the required deposits 
    and restricts the buyer from making multiple payments */

    function sendAmount(address buyer_address) public payable isBuyer(buyer_address) {
        require(msg.value == amount); // Check to see correct amount is sent.
        require(depositCheck[buyer] == 1);
        require(depositCheck[seller] == 1);
        require(amountCheck[msg.sender] == 0);
        amountCheck[msg.sender] = 1;
        emit AmountSent("Buyer has sent the payment amount to the escrow");
    }

    /* complete transaction: transferring specified amount to the seller and 
    returning deposits to both parties */
    /* NEW FUNCTION EXTRA: This should automatically pay seller when it passes expiry time (i.e. the flight time) and then automatically return deposits. Developer fee should be collected here */
    function paySeller(address buyer_address) public isBuyer(buyer_address) {
        require(depositCheck[buyer] == 1);
        require(depositCheck[seller] == 1);
        require(amountCheck[buyer] == 1);
        seller.transfer(amount);
        buyer.transfer(deposit);
        seller.transfer(deposit);
        emit SellerPaid("The seller has been paid and all deposits have been returned - transaction complete");
    }

    /*cancel transaction: refunding the specified amount to the buyer and 
    returning deposits to both parties */
    /* NEW FUNCTION EXTRA: This can only be called before the expiry time. (i.e. 1 or 2 days before flight time) and then automatically return deposits. Developer fee should be collected here */
    function refundBuyer(address seller_address) public isSeller(seller_address) {
        require(depositCheck[buyer] == 1);
        require(depositCheck[seller] == 1);
        require(amountCheck[buyer] == 1);
        buyer.transfer(amount);
        seller.transfer(deposit);
        buyer.transfer(deposit);
        emit BuyerRefunded("The buyer has been refunded and all deposits have been returned - transaction cancelled");
    }

    function getBuyer() public view returns (address){
        return buyer;
    }

    function getSeller() public view returns (address){
        return seller;
    }

    function getAmount() public view returns (uint){
        return amount;
    }

    function getDeposit() public view returns (uint){
        return deposit;
    }

    function getSignatureCount() public view returns (uint){
        return signatureCount;
    }

    function getNotes() public view returns (string memory){
        return notes;
    }

    function getIfAddressDeposited(address a) public view returns (uint){
        return depositCheck[a];
    }

    function getContractStatus() public view returns (string memory) {
        if (status == Status.OPEN){
            return "Open";
        } else if (status == Status.PENDING){
            return "Pending";
        } else{
            return "Closed";
        }
    }

    function getSignature(address a) public view returns (uint) {
        return signatures[a];
    }

    function getAmountCheck(address a) public view returns (uint){
        return amountCheck[a];
    }
}