pragma solidity >=0.7.0 <0.9.0;

// DO NOT USE ON ANY CHAIN, just for local hash generation in JS env
contract HashMachine{
    
    bytes32 public hashedChoice;
    uint256 public moreRandomNumber;
    bytes32 public hashedNumber;

    function generateRandomNumber(uint256 number) private view returns(uint256){
    return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, number)));
}
    
    function hashYourChoice(bool choice, uint256 number) public returns (bytes32) {
        moreRandomNumber = generateRandomNumber(number);
        hashedNumber=keccak256(abi.encodePacked(moreRandomNumber));
        hashedChoice = keccak256(abi.encodePacked(choice,moreRandomNumber));
        return hashedChoice;
    }
}
