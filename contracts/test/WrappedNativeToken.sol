pragma solidity ^0.8.0;

contract WrappedNativeToken {
    string public name = "Wrapped Native";
    string public symbol = "WNATIVE";
    uint8  public decimals = 18;

    mapping(address => uint) public  balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
    }

    function withdraw(uint amount) public {
        require(balanceOf[msg.sender] >= amount);
        balanceOf[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function approve(address spender, uint amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}