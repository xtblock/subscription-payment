//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SubscriptionPayment is Ownable {
    using SafeERC20 for IERC20;
    
    using Counters for Counters.Counter;
    Counters.Counter private _userIds;
    
    uint private _minSubscriptionDay = 1;
    uint private _maxSubscriptionDay = 30;
    
    struct UserDataStruct {
        uint256 _userId;
        uint256 _expiryTime;
    }
    
    mapping(address => UserDataStruct) private walletUserMap;
    
    mapping(uint256 => address) private idUserMap;
    
    uint256 private _activeTime;

    // ERC20 basic payment token contracts being held
    IERC20 private _tokenForPayment;
    
    // beneficiary of payment
    address private _newBeneficiary;
    address private _beneficiary;
    uint256 private _beneficiaryActiveTime;
    
    address private _worker;
    
    uint256 private subscriptionPrice = 24000000000000000000;//24 * 10^18 tokens per day
    
    constructor (IERC20 token_) {
         _tokenForPayment = token_;
        _activeTime = block.timestamp + 24 hours;
        _beneficiary = address(this);
        _newBeneficiary = address(this);
        _beneficiaryActiveTime = block.timestamp;
        _worker = msg.sender;
    }
    
    function getWorker() external onlyOwner view returns (address) {
        return _worker;
    }
    
    //Declare an Event
    event UpdateWorker(
        address indexed caller,
        address indexed worker
    );
    
    function updateWorker(address newWorker_) external onlyOwner {
        require(
            newWorker_ != address(0),
            "New worker is the zero address"
        );
        
        _worker = newWorker_;
        emit UpdateWorker(msg.sender, newWorker_);
    }
    
    function getActiveTime() public view returns (uint256)
    {
        return _activeTime;
    }

    function getMaxSubscriptionTime() public view returns (uint256)
    {
        return _maxSubscriptionDay;
    }
    
    //Declare an Event
    event SetMaxSubscriptionDay(
        address indexed caller,
        uint indexed maxSubscriptionDay
    );
    
    function setMaxSubscriptionDay(uint maxSubscriptionDay_) external onlyOwner {
        require(maxSubscriptionDay_ >= _minSubscriptionDay, "Subscription: Can't be less than min subscription time!");
        _maxSubscriptionDay = maxSubscriptionDay_;
        emit SetMaxSubscriptionDay(msg.sender, _maxSubscriptionDay);
    }
    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view virtual returns (address) {
        return _beneficiary;
    }
    
    //Declare an Event
    event SetBeneficiary(
        address indexed caller,
        address indexed beneficiary_,
        uint256 indexed activeTime
    );
    
    function setBeneficiary( address beneficiary_) external onlyOwner {
        require(
            beneficiary_ != address(0),
            "New beneficiary is the zero address"
        );
        
        _newBeneficiary = beneficiary_;
        _beneficiaryActiveTime = block.timestamp + 24 hours;
        
        emit SetBeneficiary(msg.sender, beneficiary_, _beneficiaryActiveTime);
    }
    
    //Declare an Event
    event SetSubscriptionPrice(
        address indexed caller,
        uint indexed newSubscriptionPrice
    );
    
    function setSubscriptionPrice(uint256 newSubscriptionPrice) external onlyOwner {
        subscriptionPrice = newSubscriptionPrice;
        emit SetSubscriptionPrice(msg.sender, newSubscriptionPrice);
    }
    
    function getSubscriptionPrice() public view virtual returns (uint256) {
        return subscriptionPrice;
    }
    
    function getCurrentUserId() public view virtual returns (uint256) {
        return  _userIds.current();
    }
    /**
     * @return the token being held.
     */
     
    function paymentToken() public view virtual returns (IERC20) {
        return _tokenForPayment;
    }
    
    //Declare an Event
    event SetTokenForPayment(
        address indexed caller,
        IERC20 indexed token_
    );
    
    function setTokenForPayment(IERC20 token_) external onlyOwner {
        _tokenForPayment = token_;
        emit SetTokenForPayment(msg.sender, token_);
    }
    
    function balanceTokenForPayment() public view virtual returns (uint256) {
        return paymentToken().balanceOf(address(this));
    }
    
    //Declare an Event
    event WithdrawTokenForPayment(
        address indexed caller,
        address indexed beneficiary_,
        uint256 indexed balance_
    );
    
    function withdrawTokenForPayment() external {
        if(_beneficiary != _newBeneficiary && block.timestamp > _beneficiaryActiveTime) _beneficiary = _newBeneficiary;
        
        require(msg.sender == _worker || msg.sender == owner(), "Invalid caller!");
        
        uint256 currentBalance = paymentToken().balanceOf(address(this));
        
        //paymentToken().safeTransferFrom(address(this), beneficiary(), currentBalance);
        paymentToken().safeTransfer(beneficiary(), currentBalance);
        emit WithdrawTokenForPayment(address(this), beneficiary(), currentBalance);
    }
    
    function getUserAddressById(uint256 userId) public view virtual returns (address) {
        return idUserMap[userId];
    }
    
    function getUserDataByAddress(address walletAddress) public view virtual returns (UserDataStruct memory) {
        return walletUserMap[walletAddress];
    }
    //Declare an Event
    event ExtendedSubscription(
        address indexed caller,
        uint256 indexed newExpiryTime
    );
    
    function extendSubscription(uint numOfDay)
        public 
    {
        require(
            block.timestamp > getActiveTime(),
            "ActiveTime: You can't extend subscription before the active time."
        );
        
        if(_beneficiary != _newBeneficiary && block.timestamp > _beneficiaryActiveTime) _beneficiary = _newBeneficiary;
        
        if(walletUserMap[msg.sender]._userId != 0){
            uint subscriptionTimeLeft = (walletUserMap[msg.sender]._expiryTime - block.timestamp) / 86400;
            if(subscriptionTimeLeft > 0){
                require(numOfDay >= _minSubscriptionDay && (numOfDay + subscriptionTimeLeft) <= _maxSubscriptionDay, "Subscription: Can't be out of min and max subscription time!");
            }
            
            require(paymentToken().balanceOf(msg.sender) >= numOfDay * getSubscriptionPrice(), "Can't pay subscription fee!");
            
            if(walletUserMap[msg.sender]._expiryTime < block.timestamp){
                walletUserMap[msg.sender]._expiryTime = block.timestamp + numOfDay * 86400;
            }else{
                walletUserMap[msg.sender]._expiryTime = walletUserMap[msg.sender]._expiryTime + numOfDay * 86400;
            }
            
            paymentToken().safeTransferFrom(msg.sender, beneficiary(), numOfDay * getSubscriptionPrice());
        }
        else{
            require(numOfDay >= _minSubscriptionDay && numOfDay <= _maxSubscriptionDay, "Subscription: Can't be out of min and max subscription time!");
            require(paymentToken().balanceOf(msg.sender) >= numOfDay * getSubscriptionPrice(), "Can't pay subscription fee!");
            paymentToken().safeTransferFrom(msg.sender, beneficiary(), numOfDay * getSubscriptionPrice());
            
            _userIds.increment();
            uint256 userId = _userIds.current();
            walletUserMap[msg.sender]._userId = userId;
            walletUserMap[msg.sender]._expiryTime = block.timestamp + numOfDay * 86400;
            
            idUserMap[userId] = msg.sender;
        }
        
        //Emit an event
        emit ExtendedSubscription(msg.sender, walletUserMap[msg.sender]._expiryTime);
    }
}
