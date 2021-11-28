pragma solidity >=0.7.0 <0.9.0;

contract MatchingPennies {

    mapping(address => uint256) public balance; //store funds deposited by players

    // state of the game
    bool playerAmadechoice; // A check money + commit
    bool playerBmadechoice; // B check money + bool
    bool playerAreveal; //check if A revealed their choice


    // commitment scheme
    address public playerA;
    bytes32 public playerAhash; //hashed input
    bool public playerArevealedSecret; // revealed boolean selected by player A
    bytes32 hashedNumber; //for validation of hash

    address public playerB;
    bool public playerBchoice;

    // timers - initialize with max value
    uint256 limitForResponseB = 2**256-1;
    uint256 limitForRevealA = 2**256-1;


    // events to monitor contract activity
    event playerA_StartedGame(address PlayerA, uint256 sentAmount);
    event playerB_JoinedGame(address PlayerB, uint256 sentAmount);
    event playerA_Canceled(address PlayerA);
    event playerB_ClaimsTimeOut(address PlayerB);
    event Withdrawal(address Player, uint256 amountWithdrawn);
    event Winner(address Winner);


    // both player places are available when the contract is deployed
    constructor() {
       playerAmadechoice=false;
       playerBmadechoice=false;
       playerAreveal=false;
    }

    // Player A starts the game by sending >1ETH and making a commitment.
    function playerA_StartGame(bytes32 commitment,bytes32 num) public payable {
        require(playerAmadechoice==false, "There is already someone who started the game.");
        require(playerBmadechoice==false, "Wait, there is already someone playing.");
        require(((msg.value >= 1.005 ether)||(balance[msg.sender]>= 1.005 ether)), "You must send at least 1.005 ETH to play the game.");
        playerAhash = commitment;
        hashedNumber=num;
        playerAmadechoice=true;
        limitForResponseB = block.timestamp + 15 minutes; //automatic expiry
        balance[msg.sender] += msg.value; //add funds to the player's balance
        emit playerA_StartedGame(msg.sender, msg.value);
    }

    // option for player A to cancel game in case player B does not join within 15 minutes
    // all funds will be sent back to player A
    function playerA_ClaimTimeOut() public {
        require(msg.sender == playerA);
        require(playerAmadechoice==true);
        require(playerBmadechoice==false);
        require(limitForResponseB<block.timestamp); // if player B does not join within 15 minutes
        uint256 amountToReturn = balance[msg.sender];
        balance[msg.sender] = 0;
        playerAmadechoice=false;
        payable(msg.sender).transfer(amountToReturn); // playerA withdhdraws all their funds
        emit playerA_Canceled(msg.sender);
    }

    // Player B is the second player joining the game
    function playerB_JoinGame(bool choice) public payable {
        require(limitForResponseB>block.timestamp); //check whether player joined within 15 minutes
        require(playerAmadechoice==true, "First player did not start the game.");
        require(playerBmadechoice==false, "Wait, there is already someone playing.");
        require(((msg.value >= 1.005 ether)||(balance[msg.sender]>= 1.005 ether)), "You must send at least 1.005 ETH to play the game.");
        limitForRevealA = block.timestamp + 20 minutes; //automatic expiry
        playerB = msg.sender;
        playerBchoice = choice;
        playerBmadechoice=true;
        balance[msg.sender] += msg.value; //add funds to the player's balance
        emit playerB_JoinedGame(msg.sender, msg.value);
    }

    // player B automatically wins and can claim reward if player A does not reveal their choice within 20 minutes
    // this function can only be initiated by player B after both players played and A does not reveal
    function playerB_ClaimTimeOut() public {
        require(msg.sender == playerB);
        require(playerAmadechoice==true);
        require(playerBmadechoice==true);
        require(playerAreveal==false);
        require(limitForRevealA<block.timestamp);

       // restore the initial state
        playerAmadechoice=false;
        playerBmadechoice=false;

        uint256 amountToReturn = 1 ether; //fees 0.000005 ETH not taken into account as a penalty
        balance[playerA] = balance[playerA] - amountToReturn;
        require(balance[playerA]>= 0, "underflow detected");

        balance[playerB] = balance[playerB] + amountToReturn;
        require(balance[playerB]>= 0, "underflow detected");

        emit playerB_ClaimsTimeOut(msg.sender);

    }

    // after both players made a choice, player A reveals their choice
    // hash of commitment as well as hash of number used in commitment is checked
    // if choices equal and hash correct and hash of random number correct then player A wins and gets 1 ETH
    // if A dishonest or choices different then player B wins and gets 1 ETH
    function playerA_RevealSecret(bool choice, uint256 number) public {
        require(playerAmadechoice==true, "Both players must first deposit funds and make a commitment to a bool.");
        require(playerBmadechoice==true, "Waiting for 2nd player to play.");
        require(msg.sender==playerA);
        require(limitForRevealA>block.timestamp); //check 20 minutes time limit

        playerArevealedSecret = choice; //store the choice which player A revealed

        // restore the initial state
        playerAreveal=true;
        playerAmadechoice=false;
        playerBmadechoice=false;

         // player A wins if choices are the same and playerA is honest
        if (playerBchoice== playerArevealedSecret && keccak256(abi.encodePacked(choice,number))==playerAhash &&  keccak256(abi.encodePacked(number))==hashedNumber){

        uint256 amountToReturn = 1.00005 ether; // player B gives some fee payment to A
        balance[playerB] = balance[playerB] - amountToReturn;
        require(balance[playerB]>= 0, "underflow detected");

        balance[playerA] = balance[playerA] + amountToReturn;
        require(balance[playerA]>= 0, "underflow detected");

        emit Winner(playerA);


        } else {

        uint256 amountToReturn = 0.99995 ether; // player B gives some fee payment to A
        balance[playerA] = balance[playerA] - amountToReturn;
        require(balance[playerA]>= 0, "underflow detected");

        balance[playerB] = balance[playerB] + amountToReturn;
        require(balance[playerB]>= 0, "underflow detected");
         emit Winner(playerB);
        }
    }

    // allows players to check their balance
    function checkBalance() public view returns (uint256) {
        return balance[msg.sender];
    }

    // allows players to withdraw (all) funds if there is no game in progress
    // can only be initiated when there is no game in progress
    // pull design - each player has to withdraw funds and pay fee
    function withdrawFunds() public {
        require(msg.sender==playerA||msg.sender==playerB);
        require((playerAmadechoice==false&&playerBmadechoice==false));

        uint256 amountToReturn = balance[msg.sender];
        require(amountToReturn>= 0, "something went wrong");
        balance[msg.sender] = 0;
        payable(msg.sender).transfer(amountToReturn);
        emit Withdrawal(msg.sender, amountToReturn);
    }
}
