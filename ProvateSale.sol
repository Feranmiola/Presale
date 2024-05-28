// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Presale is Initializable{

    address public admin;
    IERC20Upgradeable public token;

    event AdminWithdrawal(uint bnbAmount, uint tokenAmount);

    //Presale
    uint256 public bnbunit;
    uint256 public hardCap;
    uint256 public raisedBNB;

    mapping(address => uint) public spentBNB;
    mapping(address => uint) public boughtTokens;
    uint256 public maximumPerAddress;
    uint256 public minimumPerAddress;
    

    bool public presaleStart;
    bool public presaleEnd;

    //Vesting
     
    struct VestingPriod{
        uint percent;
        uint startTime;
        uint vestingCount;
       uint MaxClaim;   
    }
    
    uint maxPercent;
    bool Vesting;
    uint VestingCount;

    VestingPriod _vestingPeriod;

    mapping(uint => VestingPriod ) public PeriodtoPercent;
    mapping(address => uint) private TotalBalance;
    mapping(address => uint) private claimCount;
    mapping(address => uint) private claimedAmount;
    mapping(address => uint) private claimmable;
    mapping(address => bool) public whitelisted;




    function initialize(address _token, uint buyUnit, uint max, uint min, uint hardcap) external initializer{
        
        admin = payable(msg.sender);
        token = IERC20Upgradeable(_token);

        hardCap = hardcap;
        bnbunit = buyUnit;  
        maximumPerAddress = max;
        minimumPerAddress = min;     
    } 

    //Presale
    function startPresale() external {
        require(msg.sender == admin);
        uint tokenBalance = hardCap * bnbunit;

        require(tokenBalance <= token.balanceOf(address(this)));

        presaleStart = true; 
    }



    function buy(uint amount) external{
        require(presaleStart, "PO"); //Presale Off
        require(amount > minimumPerAddress, "Not Reaching Minimum");
        require(spentBNB[msg.sender]+ amount <= maximumPerAddress, "Exceeding Limit");
        require(raisedBNB + amount <= hardCap, "TM");//Too much, gone over hard cap
        require(whitelisted[msg.sender], "Not Whitelisted");

        token.transferFrom(msg.sender, address(this), amount);

        uint256 tokenAmount = amount * bnbunit;

        spentBNB[msg.sender]+=amount;
        boughtTokens[msg.sender]+=tokenAmount;
        TotalBalance[msg.sender] +=tokenAmount;
        raisedBNB+=amount;

        


    }

    function emergencyWithdrawal(uint amount) external{
        require(presaleStart, "PO");
        require(spentBNB[msg.sender] >= amount);

        uint tokenDebit = amount * bnbunit;

        boughtTokens[msg.sender] -= tokenDebit;
        spentBNB[msg.sender] -= amount;

       (bool sent,) = msg.sender.call{value: amount}("");
        require(sent, "Fail");

        

    }

    function endPresale() external{
        require(msg.sender == admin, "NA");//Not admin
        require(presaleStart, "PO");//Presale Off

        presaleStart = false;
        presaleEnd = true;

    }
    
    //Vesting 

    
    function setVesting(uint[] calldata time, uint[] calldata percentage) external{
        require(msg.sender==admin, "NA");

        for(uint i=0; i< time.length; i++){
            _setVesting(time[i], percentage[i]);
        }
    }

    function _setVesting(uint StartTime, uint StartPercentage) internal {
           VestingCount++;
           maxPercent += StartPercentage;

        if(maxPercent > 100){
            maxPercent -=StartPercentage;
            revert ();
        }
        else {
            require(StartTime > PeriodtoPercent[VestingCount-1].startTime);
        PeriodtoPercent[VestingCount] = VestingPriod({
            percent : StartPercentage,
            startTime : StartTime,
            vestingCount : VestingCount,
              MaxClaim : maxPercent
        });

        }
    }
 
    function claim() external {
        require(presaleEnd, "PA");
        require(claimCount[msg.sender] <= VestingCount,"CC");//Claiming Complete
    
        for(uint i = claimCount[msg.sender]; i<= VestingCount; i++){
            if(PeriodtoPercent[i].startTime <= block.timestamp){
                claimmable[msg.sender] +=PeriodtoPercent[i].percent;
                claimCount[msg.sender] ++;
            }
            else 
            break;
        }
        
            
        require(claimmable[msg.sender] <= 100);
        

        uint _amount = (claimmable[msg.sender] *100) * TotalBalance[msg.sender]/10000;

        boughtTokens[msg.sender] -= _amount;
        claimedAmount[msg.sender] += claimmable[msg.sender]; 
  
        delete claimmable[msg.sender];
        delete spentBNB[msg.sender];

        token.transfer(msg.sender, _amount);


    }

    function addAddresstoWhitelist(address[] calldata newAddress) external{
        require(msg.sender==admin, "NA");

            for(uint i=0; i <= newAddress.length; i++){
                internalSetWhitelist(newAddress[i]);
            }
    }

    function internalSetWhitelist(address newAddress) internal{
        whitelisted[newAddress] = true;
    }

    //Admin Withdrawal

    function WithdrawRemainingFunds() external{
        require(msg.sender==admin, "NA");
        uint tokenBalance = token.balanceOf(address(this));

        if(raisedBNB < hardCap || tokenBalance > 0){
            token.transfer(admin, token.balanceOf(address(this)));
        }

         (bool sent,) = admin.call{value: raisedBNB}("");
        require(sent, "Fail");

    }

    
    function TotalRaised() external view returns(uint){
        return raisedBNB;
    }

    function getSpent() external view returns(uint){
        return spentBNB[msg.sender];
    }
    function getBal() external view returns(uint){
        return TotalBalance[msg.sender];
    }

    
}